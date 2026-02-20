# Servicios Web en .net

## ¿Puedes mostrarme un prototipo de microservicio (por ejemplo lista de todo) escrita en .net y explicar los diferentes componentes?

Para construir un microservicio de
Lista de Tareas (Todo List) en .NET, lo ideal es seguir una arquitectura que
separe las responsabilidades para facilitar el mantenimiento y la escalabilidad.

1. Estructura de un Prototipo en .NET

Un microservicio estándar suele dividirse en estas capas principales dentro de un proyecto ASP.NET Core Web API: 

```csharp
// 1. Modelo de Dominio (Entidad)
public class TodoItem {
    public int Id { get; set; }
    public string Title { get; set; }
    public bool IsCompleted { get; set; }
}

// 2. Capa de Datos (DB Context con Entity Framework)
public class TodoContext : DbContext {
    public TodoContext(DbContextOptions<TodoContext> options) : base(options) { }
    public DbSet<TodoItem> TodoItems { get; set; }
}

// 3. Capa de Exposición (API Controller)
[ApiController]
[Route("api/[controller]")]
public class TodoController : ControllerBase {
    private readonly TodoContext _context;
    public TodoController(TodoContext context) => _context = context;

    [HttpGet]
    public async Task<ActionResult<IEnumerable<TodoItem>>> GetTodos() 
        => await _context.TodoItems.ToListAsync();

    [HttpPost]
    public async Task<ActionResult<TodoItem>> PostTodo(TodoItem item) {
        _context.TodoItems.Add(item);
        await _context.SaveChangesAsync();
        return CreatedAtAction(nameof(GetTodos), new { id = item.Id }, item);
    }
}
```

> Usa el código con precaución.

2.  Componentes de la Arquitectura de Microservicios
    Para que este pequeño servicio funcione en un ecosistema real, se apoya en
    estos componentes clave: 

    - **API Gateway**: Es el punto de entrada único para los clientes. Redirige
      las solicitudes al microservicio de "Tareas", ocultando la complejidad
      interna del sistema.
    - **Base de Datos por Servicio**: Cada microservicio debe tener su propia
      base de datos (p. ej., SQL Server o MongoDB) para asegurar el acoplamiento
      suelto.
    - **Comunicación Asíncrona (Event Bus)**: Si al marcar una tarea como
      "completada" se debe notificar a otro servicio (ej. "Estadísticas"), se
      usan mensajes a través de herramientas como RabbitMQ o Azure Service Bus.
    - **Contenedores (Docker)**: El microservicio se empaqueta junto con sus
      dependencias en una imagen de Docker para que corra igual en cualquier
      entorno.
    - **Service Discovery**: Permite que los servicios se encuentren entre sí
      automáticamente sin necesidad de rutas fijas (IPs estáticas). 

Recursos Recomendados

    - **Guía Oficial**: Revisa la Arquitectura de Microservicios de Microsoft
      para patrones avanzados como CQRS o DDD.
    - **Ejemplo Práctico**: Puedes explorar el repositorio de referencia
      eShopOnContainers en GitHub que muestra estos conceptos aplicados a
      escala.

¿Te gustaría que profundicemos en cómo configurar el archivo Dockerfile para
desplegar este microservicio o prefieres ver cómo implementar la comunicación
entre dos servicios?

## ¿Puedes refactorizar para que los TDO se definan como Record?

¡Excelente elección! Usar record en C# es la forma más limpia y moderna de
manejar DTOs (Data Transfer Objects), ya que son inmutables por defecto y
reducen drásticamente el código repetitivo (boilerplate).

Aquí tienes el prototipo refactorizado usando Positional Records:

1. Definición del DTO con Records
   En lugar de una clase pesada, definimos el contrato de datos en una sola
   línea:

```csharp
// DTO para la creación (Inmutable y conciso)
public record CreateTodoRequest(string Title);

// DTO para la respuesta (Incluye ID y estado)
public record TodoResponse(int Id, string Title, bool IsCompleted);
```

> Usa el código con precaución.

2. Implementación en el Controlador
   Al usar record, el mapeo se vuelve mucho más explícito y seguro:

```csharp
[ApiController]
[Route("api/[controller]")]
public class TodoController : ControllerBase {
    private readonly TodoContext _context;
    public TodoController(TodoContext context) => _context = context;

    [HttpPost]
    public async Task<ActionResult<TodoResponse>> PostTodo(CreateTodoRequest request) {
        // Mapeo de DTO a Entidad de dominio
        var todo = new TodoItem { 
            Title = request.Title, 
            IsCompleted = false 
        };

        _context.TodoItems.Add(todo);
        await _context.SaveChangesAsync();

        // Mapeo de Entidad a DTO de respuesta usando el constructor posicional
        var response = new TodoResponse(todo.Id, todo.Title, todo.IsCompleted);

        return CreatedAtAction(nameof(PostTodo), new { id = todo.Id }, response);
    }
}
```

> Usa el código con precaución.

¿Por qué usar record para DTOs?

    - **Inmutabilidad**: Una vez que el DTO se recibe en el controlador, no
      debería cambiar. Los records protegen la integridad de los datos durante
      el flujo de la solicitud.
    - **Igualdad por Valor**: Dos records con los mismos datos son considerados
      iguales, lo cual es ideal para pruebas unitarias.
    - **Sintaxis with**: Si necesitas copiar un DTO cambiando solo una
      propiedad, puedes usar:
      `var actualizado = original with { IsCompleted = true };`.

Para proyectos más grandes, te recomiendo usar la librería AutoMapper en .NET
para automatizar la conversión entre tus entidades de base de datos y tus
Records DTO. También puedes validar estos registros fácilmente con
FluentValidation.

¿Quieres que implementemos un validador de entrada para estos Records o
prefieres ver cómo configurar la Inyección de Dependencias para un repositorio
de datos?

---

## Me gustaría empezar viendo como realizar la validación de entrada

Para realizar validaciones de forma elegante en microservicios .NET, la
biblioteca estándar de la industria es FluentValidation. A diferencia de los
Data Annotations (los clásicos atributos [Required]), esta permite mantener
tus Records DTO limpios y separar la lógica de negocio de la estructura del
dato.

1. Instalación
   Primero, añade el paquete necesario desde NuGet:

```bash
dotnet add package FluentValidation.AspNetCore
```

> Usa el código con precaución.

2. Definición del Validador
   Creamos una clase que herede de `AbstractValidator<T>`. Aquí es donde defines
   las reglas para tu record:

```csharp
using FluentValidation;

public record CreateTodoRequest(string Title, DateTime DueDate);

public class CreateTodoValidator : AbstractValidator<CreateTodoRequest> 
{
    public CreateTodoValidator() 
    {
        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("El título no puede estar vacío.")
            .MinimumLength(3).WithMessage("El título debe tener al menos 3 caracteres.")
            .MaximumLength(100).WithMessage("Título demasiado largo.");

        RuleFor(x => x.DueDate)
            .GreaterThan(DateTime.Now).WithMessage("La fecha de entrega debe ser en el futuro.");
    }
}
```

> Usa el código con precaución.

3. Registro en el `Program.cs`

Debes registrar tus validadores para que el contenedor de dependencias los
reconozca:

```csharp
using FluentValidation;

var builder = WebApplication.CreateBuilder(args);

// Registra todos los validadores del ensamblado actual
builder.Services.AddValidatorsFromAssemblyContaining<CreateTodoValidator>();

var app = builder.Build();
```

> Usa el código con precaución.

4. Uso en el Controlador
   Aunque puedes automatizarlo para que falle antes de entrar al método, la forma manual te da más control sobre la respuesta:

```csharp
[HttpPost]
public async Task<IActionResult> PostTodo(
    CreateTodoRequest request, 
    [FromServices] IValidator<CreateTodoRequest> validator) 
{
    var validationResult = await validator.ValidateAsync(request);

    if (!validationResult.IsValid) {
        // Retorna un 400 Bad Request con los errores detallados
        return BadRequest(validationResult.Errors.Select(e => e.ErrorMessage));
    }

    // ... lógica para guardar en DB ...
    return Ok();
}
```

> Usa el código con precaución.

Ventajas de este enfoque:

    - Separación de responsabilidaides: Tu DTO (record) solo define la forma del
      dato; el validador define la regla.
    - Testeabilidad: Puedes hacer pruebas unitarias de CreateTodoValidator sin
      levantar toda la API.
    - Reutilización: Puedes usar el mismo validador en diferentes controladores
      o servicios.

¿Te gustaría ver cómo integrar esto con un Middleware de manejo de excepciones
para que los errores de validación se capturen automáticamente y no tengas que
repetir el if (!validationResult.IsValid) en cada método?

## Veamos como se in integra un middleware para la validacion

Para integrar las validaciones de forma global y evitar repetir código en cada
controlador, crearemos un Middleware que capture excepciones personalizadas y
las devuelva con un formato estandarizado (RFC 7807).

1. Crear una Excepción Personalizada
   Primero, definimos una excepción que transporte los errores de validación
   desde cualquier capa (Service o API).

```csharp
public class ValidationAppException : Exception
{
    public IDictionary<string, string[]> Errors { get; }
    public ValidationAppException(IDictionary<string, string[]> errors) 
        => Errors = errors;
}
```

> Usa el código con precaución.

2. Implementar el Middleware
   Este componente intercepta cualquier excepción de validación y la transforma
   en una respuesta 400 Bad Request limpia.

```csharp
public class ValidationExceptionMiddleware
{
    private readonly RequestDelegate _next;

    public ValidationExceptionMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        try {
            await _next(context);
        }
        catch (ValidationAppException ex) {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            context.Response.ContentType = "application/json";

            var response = new { 
                Title = "Errores de validación", 
                Status = 400, 
                Errors = ex.Errors 
            };

            await context.Response.WriteAsJsonAsync(response);
        }
    }
}
```

> Usa el código con precaución.

3. Automatizar la Validación (Filtro o Acción)
   Para que no tengas que llamar a validator.ValidateAsync manualmente, lo ideal
   es usar un Action Filter o inyectarlo en el flujo. Sin embargo, en
   arquitecturas modernas como Clean Architecture, esto se suele delegar a un
   Behavior de MediatR.
   Si prefieres mantenerlo simple en el controlador sin el if, lanza la
   excepción:

```csharp
[HttpPost]
public async Task<IActionResult> PostTodo(CreateTodoRequest request, [FromServices] IValidator<CreateTodoRequest> validator) 
{
    var result = await validator.ValidateAsync(request);
    
    if (!result.IsValid) {
        // El middleware capturará esto y lo enviará al cliente
        throw new ValidationAppException(result.ToDictionary());
    }

    // Lógica limpia aquí...
    return Ok();
}
```

> Usa el código con precaución.

4. Registro en `Program.cs`
   No olvides registrar el middleware al inicio del pipeline de ASP.NET Core:

```csharp
var app = builder.Build();

// Debe ir antes de los controladores para capturar sus errores
app.UseMiddleware<ValidationExceptionMiddleware>();

app.MapControllers();
app.Run();
```

> Usa el código con precaución.

Por qué esta arquitectura es superior:

    - Controles Limpios: Tus métodos de API solo contienen lógica de flujo, no
      de manejo de errores.
    - Consistencia: Todos los errores de validación en tu microservicio tendrán
      exactamente el mismo formato JSON.
    - Escalabilidad: Puedes agregar otros catch en el middleware para manejar
      errores de base de datos o de autorización de forma global.

¿Te interesa ver cómo aplicar el patrón Repository para que el controlador ni
siquiera sepa que existe una base de datos, o prefieres configurar el Swagger
para que documente estos errores?

---

## Me interesa ver cómo aplicar el patrón repository

Para implementar el Patrón Repository, desacoplaremos la lógica de acceso a
datos de los controladores. Esto facilita las pruebas unitarias
(haciendo mocking) y permite cambiar la fuente de datos (ej. de SQL a MongoDB)
sin tocar la lógica de la API.

1. Definir la Interfaz (Contrato)
   La interfaz define qué puede hacer el repositorio, sin importar el cómo.

```csharp
public interface ITodoRepository {
    Task<IEnumerable<TodoItem>> GetAllAsync();
    Task<TodoItem?> GetByIdAsync(int id);
    Task AddAsync(TodoItem item);
    Task SaveChangesAsync();
}
```

> Usa el código con precaución.

2. Implementación Concreta
   Aquí es donde inyectamos el DbContext de Entity Framework.

```csharp
public class TodoRepository : ITodoRepository {
    private readonly TodoContext _context;
    public TodoRepository(TodoContext context) => _context = context;

    public async Task<IEnumerable<TodoItem>> GetAllAsync() 
        => await _context.TodoItems.ToListAsync();

    public async Task<TodoItem?> GetByIdAsync(int id) 
        => await _context.TodoItems.FindAsync(id);

    public async Task AddAsync(TodoItem item) 
        => await _context.TodoItems.AddAsync(item);

    public async Task SaveChangesAsync() 
        => await _context.SaveChangesAsync();
}
```

> Usa el código con precaución.

3. Registro en el Contenedor de Dependencias
  En tu `Program.cs`, vinculamos la interfaz con su implementación:

```csharp
builder.Services.AddScoped<ITodoRepository, TodoRepository>();
```

> Usa el código con precaución.

4. Uso en el Controlador Refactorizado
   Ahora el controlador es mucho más ligero y no depende directamente de la base
   de datos:

```csharp
[ApiController]
[Route("api/[controller]")]
public class TodoController : ControllerBase {
    private readonly ITodoRepository _repository;
    private readonly IValidator<CreateTodoRequest> _validator;

    public TodoController(ITodoRepository repository, IValidator<CreateTodoRequest> validator) {
        _repository = repository;
        _validator = validator;
    }

    [HttpPost]
    public async Task<IActionResult> PostTodo(CreateTodoRequest request) {
        // 1. Validación (Lanzará excepción capturada por el Middleware)
        var result = await _validator.ValidateAsync(request);
        if (!result.IsValid) throw new ValidationAppException(result.ToDictionary());

        // 2. Mapeo y Persistencia a través del Repositorio
        var todo = new TodoItem { Title = request.Title };
        await _repository.AddAsync(todo);
        await _repository.SaveChangesAsync();

        return CreatedAtAction(nameof(PostTodo), new { id = todo.Id }, todo);
    }
}
```

> Usa el código con precaución.

Ventajas Clave

    - Testabilidad: Puedes crear un Mock<ITodoRepository> para probar el
      controlador sin necesidad de una base de datos real usando Moq.
    - Principio de Responsabilidad Única: El repositorio se encarga de las
      consultas; el controlador solo coordina el flujo.
    - Mantenimiento: Si decides usar Dapper para mejorar el rendimiento de las
      consultas, solo cambias la implementación de TodoRepository sin afectar al
      resto de la app.

¿Te gustaría que añadamos el Patrón Unit of Work para manejar transacciones
complejas o prefieres ver cómo Dockerizar este microservicio con su base de
datos?

## Me gustaría antes refactorizar el controlador para usar el middleware de validación de datos de entrada

Para refactorizar y eliminar el `if (!result.IsValid)` de tus métodos, la mejor
práctica en .NET es usar un Action Filter. Esto permite que la validación ocurra
automáticamente antes de que el código de tu controlador se ejecute, lanzando la
excepción que tu middleware ya sabe capturar.

1. Crear el Filtro de Validación Automática
   Este filtro interceptará la solicitud, buscará un validador registrado para
   el DTO y, si falla, lanzará la ValidationAppException.

```csharp
using FluentValidation;
using Microsoft.AspNetCore.Mvc.Filters;

public class ValidationFilter : IAsyncActionFilter
{
    private readonly IServiceProvider _serviceProvider;
    public ValidationFilter(IServiceProvider serviceProvider) => _serviceProvider = serviceProvider;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        // Buscamos si algún argumento del método tiene un validador
        foreach (var argument in context.ActionArguments.Values)
        {
            if (argument == null) continue;

            var validatorType = typeof(IValidator<>).MakeGenericType(argument.GetType());
            var validator = _serviceProvider.GetService(validatorType) as IValidator;

            if (validator != null)
            {
                var result = await validator.ValidateAsync(new ValidationContext<object>(argument));
                if (!result.IsValid)
                {
                    // Lanzamos la excepción que captura nuestro Middleware
                    throw new ValidationAppException(result.ToDictionary());
                }
            }
        }

        await next();
    }
}
```

> Usa el código con precaución.

2. Registrar el Filtro Globalmente
   En `Program.cs`, añadimos el filtro para que aplique a todos los
   controladores automáticamente:

```csharp
builder.Services.AddControllers(options => 
{
    options.Filters.Add<ValidationFilter>();
});
```

> Usa el código con precaución.

3. El Controlador "Limpio" (Refactorizado)
   Ahora tu controlador no tiene lógica de validación ni de manejo de errores. Es puramente declarativo:

```csharp
[ApiController]
[Route("api/[controller]")]
public class TodoController : ControllerBase 
{
    private readonly ITodoRepository _repository;

    public TodoController(ITodoRepository repository) => _repository = repository;

    [HttpPost]
    public async Task<ActionResult<TodoResponse>> PostTodo(CreateTodoRequest request) 
    {
        // Si el código llega aquí, los datos YA son válidos
        var todo = new TodoItem { Title = request.Title };
        
        await _repository.AddAsync(todo);
        await _repository.SaveChangesAsync();

        return Ok(new TodoResponse(todo.Id, todo.Title, todo.IsCompleted));
    }
}
```

> Usa el código con precaución.

¿Qué logramos con esto?

    - Cero Boilerplate: No más `if (!ModelState.IsValid)` o
      `validator.ValidateAsync` en cada endpoint.
    - Arquitectura Declarativa: El comportamiento se define por configuración,
      no por repetición.
    - Seguridad: Es imposible que un desarrollador olvide validar una entrada si
      el DTO tiene un validador asociado en el proyecto.

Para llevar esto a producción, es vital la Observabilidad. ¿Quieres ver cómo
configurar Serilog para que el Middleware registre estos errores en la consola,
o pasamos a empaquetar todo en Docker?

---

## Me interesa ver la parte de Observabilidad

Para implementar Observabilidad en microservicios .NET, no basta con escribir
archivos de texto; necesitamos Logs Estructurados. Esto permite que herramientas
como Elasticsearch o Azure Monitor puedan filtrar por campos específicos (como
UserId o ErrorCode) en lugar de buscar texto plano.

1. Instalación de Serilog
   Instala los paquetes de Serilog desde NuGet para integrarlo con el pipeline de .NET:

```bash
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Sinks.Console
```

> Usa el código con precaución.

2. Configuración en `Program.cs`

Configura Serilog para que capture todos los eventos del sistema desde el
arranque:

```csharp
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// Configurar Serilog
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .Enrich.FromLogContext() // Agrega información del contexto de la petición
    .CreateLogger();

builder.Host.UseSerilog();
```

> Usa el código con precaución.

3. Refactorización del Middleware para Observabilidad
   Ahora, el middleware no solo transforma el error para el cliente, sino que
   registra el incidente con telemetría útil para el equipo de desarrollo:

```csharp
public class ValidationExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ValidationExceptionMiddleware> _logger; // Inyectar Logger

    public ValidationExceptionMiddleware(RequestDelegate next, ILogger<ValidationExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try {
            await _next(context);
        }
        catch (ValidationAppException ex) {
            // Log Estructurado: Guardamos los errores como un objeto, no como string
            _logger.LogWarning("Intento de solicitud inválida. Errores: {@ValidationErrors}", ex.Errors);

            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsJsonAsync(new { 
                Title = "Error de Validación", 
                Errors = ex.Errors 
            });
        }
        catch (Exception ex) {
            // Captura de errores críticos no controlados
            _logger.LogError(ex, "Ocurrió un error no controlado en el sistema");
            context.Response.StatusCode = 500;
            await context.Response.WriteAsJsonAsync(new { Title = "Error Interno" });
        }
    }
}
```

> Usa el código con precaución.

4. Health Checks (Monitoreo de Salud)

Un microservicio debe informar si está "vivo". Registra el middleware de Health
Checks oficial:

```csharp
// En Program.cs
builder.Services.AddHealthChecks()
    .AddDbContextCheck<TodoContext>(); // Verifica si la DB está accesible

var app = builder.Build();
app.MapHealthChecks("/health"); // Endpoint para Kubernetes o Azure
```

> Usa el código con precaución.

Por qué esto es vital en Microservicios:

    - Logs Estructurados: El uso de `{@ValidationErrors}` (con el símbolo @)
      permite que Serilog serialice el objeto completo, facilitando búsquedas
      complejas en dashboards.
    - Correlación: En un entorno real, podrías añadir un CorrelationId para
      rastrear una petición a través de múltiples microservicios.
    - Health Checks: Permiten que el orquestador (como Kubernetes) reinicie el
      contenedor automáticamente si la conexión a la base de datos falla.

¿Quieres que veamos cómo empaquetar todo esto en un Dockerfile multietapa o
prefieres implementar OpenTelemetry para ver trazas visuales de las peticiones?

## Me gustaría ver cómo implementar OpenTelemetry

Implementar OpenTelemetry (OTel) es el estándar de oro para la observabilidad
moderna. Te permite rastrear una solicitud desde que entra al API Gateway hasta
que toca la base de datos, generando Trazas (Traces) visuales que facilitan
encontrar cuellos de botella.

1. Instalación de Paquetes
   Añade las librerías necesarias de OpenTelemetry .NET:

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.EntityFrameworkCore
dotnet add package OpenTelemetry.Exporter.Console # Para ver las trazas en consola


Usa el código con precaución.
2. Configuración en Program.cs
Configuramos el pipeline para capturar automáticamente métricas y trazas de la API y de Entity Framework:
csharp

using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService("TodoMicroservice"))
        .AddAspNetCoreInstrumentation() // Rastrea peticiones HTTP entrantes
        .AddEntityFrameworkCoreInstrumentation() // Rastrea consultas a la DB
        .AddConsoleExporter()); // En producción, usa .AddOtlpExporter() para enviarlo a Jaeger o Grafana

Usa el código con precaución.
3. Visualización en el Middleware
Podemos enriquecer nuestras trazas cuando ocurre un error de validación, permitiendo que en el panel de control (como Jaeger o Zipkin) aparezca el evento de error asociado a la petición:
csharp

// Dentro del catch en ValidationExceptionMiddleware
var activity = System.Diagnostics.Activity.Current;
activity?.SetTag("validation.status", "failed");
activity?.AddEvent(new System.Diagnostics.ActivityEvent("Validation Failed"));

Usa el código con precaución.
4. ¿Cómo se ve esto en acción?
Al realizar una petición, verás en tu consola (o herramienta de visualización) un objeto JSON estructurado que muestra:

    TraceId: Identificador único de toda la transacción.
    SpanId: Identificador de este paso específico (ej. la consulta SQL).
    Duration: Exactamente cuánto tiempo tomó la validación, la lógica y la base de datos por separado.

Siguiente Paso Lógico
Ahora que tu microservicio es mantenible (Repository), seguro (FluentValidation), limpio (Middleware) y observable (OpenTelemetry), el siguiente paso es la portabilidad.
¿Deseas generar el Dockerfile multietapa para que este microservicio pueda ejecutarse en cualquier clúster, o quieres configurar Jaeger para ver estas trazas de forma gráfica?

---

## Vamos a generar el Dockerfile multi etapa

Para un microservicio en .NET, un
Dockerfile multietapa (multi-stage) es esencial: permite compilar la aplicación con el SDK completo pero genera una imagen final ligera que solo contiene el runtime, reduciendo el tamaño y mejorando la seguridad.
Aquí tienes el archivo Dockerfile optimizado para tu microservicio de Todo List:
dockerfile

# --- ETAPA 1: Compilación (Build) ---
FROM ://mcr.microsoft.com AS build
WORKDIR /src

# Copiar archivos de proyecto y restaurar dependencias (optimiza la caché de capas)
COPY ["TodoApi.csproj", "./"]
RUN dotnet restore "TodoApi.csproj"

# Copiar el resto del código y compilar
COPY . .
RUN dotnet build "TodoApi.csproj" -c Release -o /app/build

# --- ETAPA 2: Publicación (Publish) ---
FROM build AS publish
RUN dotnet publish "TodoApi.csproj" -c Release -o /app/publish /p:UseAppHost=false

# --- ETAPA 3: Runtime Final (Final) ---
FROM ://mcr.microsoft.com AS final
WORKDIR /app

# Exponer los puertos que usa .NET por defecto
EXPOSE 8080
EXPOSE 8081

# Copiar solo los binarios necesarios desde la etapa de publicación
COPY --from=publish /app/publish .

# Definir el punto de entrada
ENTRYPOINT ["dotnet", "TodoApi.dll"]

Usa el código con precaución.
Componentes Clave de este Dockerfile:

    Imágenes base de Microsoft: Se utiliza la imagen sdk para compilar y la imagen aspnet para ejecutar. Esta última es mucho más pequeña y segura.
    Caché de capas: Al ejecutar dotnet restore antes de copiar todo el código, Docker guardará las dependencias en caché. Si cambias una línea de código pero no las librerías, el despliegue será mucho más rápido.
    Seguridad: El runtime de .NET 8 ahora usa por defecto el puerto 8080 y se ejecuta bajo un usuario no privilegiado para mejorar la postura de seguridad del contenedor.
    Entorno de Producción: El flag -c Release asegura que el código esté optimizado, sin símbolos de depuración pesados.

Cómo construirlo y ejecutarlo:
Para construir la imagen y levantar el contenedor junto con tu base de datos, lo ideal es usar el Docker Desktop Dashboard o la línea de comandos:
bash

# Construir la imagen
docker build -t todo-microservice .

# Ejecutar el contenedor
docker run -d -p 5000:8080 --name my-todo-api todo-microservice

Usa el código con precaución.
¿Te gustaría crear un archivo Docker Compose para levantar simultáneamente el microservicio y una base de datos SQL Server o PostgreSQL?

## Me gustaría crear un Docker Compose para levantar simultaneamente el microservicio y una base de datos SQL Server o PostgreSQL

Pensando
Para levantar el ecosistema completo, utilizaremos
Docker Compose. Esto automatiza la creación de la red interna para que el microservicio pueda comunicarse con SQL Server usando el nombre del servicio en lugar de una dirección IP variable.
1. Archivo docker-compose.yml
Crea este archivo en la raíz de tu solución:
yaml

services:
  database:
    image: ://mcr.microsoft.com
    container_name: todo-db
    environment:
      - ACCEPT_EULA=Y
      - MSSQL_SA_PASSWORD=YourStrong@Password123
    ports:
      - "1433:1433"

  todo-api:
    image: todo-microservice
    build:
      context: .
      dockerfile: Dockerfile
    container_name: todo-api
    depends_on:
      - database
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__DefaultConnection=Server=database;Database=TodoDb;User Id=sa;Password=YourStrong@Password123;TrustServerCertificate=True
    ports:
      - "5000:8080"

Usa el código con precaución.
2. Ajuste en el Microservicio
Asegúrate de que en tu Program.cs estés leyendo la cadena de conexión desde las variables de entorno. El nombre del servidor debe ser database (el nombre del servicio definido en el compose):
csharp

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<TodoContext>(options =>
    options.UseSqlServer(connectionString));

Usa el código con precaución.
3. Comandos Principales
Para poner todo en marcha, utiliza la terminal en la carpeta del proyecto:

    Levantar todo: docker-compose up -d (el flag -d corre en segundo plano).
    Ver logs: docker-compose logs -f todo-api (ideal para ver los logs de Serilog y OpenTelemetry que configuramos).
    Detener todo: docker-compose down.

Consideraciones de Producción

    Persistencia: En un escenario real, deberías añadir un volume al servicio database para que los datos no se borren al detener el contenedor.
    Health Checks: SQL Server tarda unos segundos en arrancar. Puedes usar el Docker Compose Healthcheck para que la API espere a que la base de datos esté "realmente" lista antes de intentar conectar.

¿Te gustaría que añadamos un contenedor de Jaeger al archivo Compose para visualizar gráficamente las trazas de OpenTelemetry que configuramos antes?

---

## Me gustaría agregar un contenedor de Jaeger

Para completar el ecosistema de observabilidad, añadiremos
Jaeger al archivo de orquestación. Esto te permitirá ver de forma gráfica el recorrido de cada petición, desde que llega al controlador hasta que ejecuta la consulta en SQL Server.
1. Actualización del docker-compose.yml
Añadimos el servicio de Jaeger y configuramos la API para que le envíe las trazas mediante el protocolo OTLP.
yaml

services:
  database:
    image: ://mcr.microsoft.com
    environment:
      - ACCEPT_EULA=Y
      - MSSQL_SA_PASSWORD=YourStrong@Password123
    ports:
      - "1433:1433"

  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger-ui
    ports:
      - "16686:16686" # Interfaz Web (UI)
      - "4317:4317"   # Puerto OTLP (gRPC) para recibir trazas

  todo-api:
    build: .
    depends_on:
      - database
      - jaeger
    environment:
      - ConnectionStrings__DefaultConnection=Server=database;Database=TodoDb;User Id=sa;Password=YourStrong@Password123;TrustServerCertificate=True
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317
    ports:
      - "5000:8080"

Usa el código con precaución.
2. Ajuste en el Microservicio (Program.cs)
Debemos cambiar el exportador de consola por el de OTLP (OpenTelemetry Protocol) para que los datos viajen hacia Jaeger. Primero, instala el paquete:
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
Y actualiza la configuración:
csharp

builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddSource("TodoMicroservice")
        .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService("TodoMicroservice"))
        .AddAspNetCoreInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        // Enviamos las trazas al endpoint configurado en Docker
        .AddOtlpExporter(opt => {
            opt.Endpoint = new Uri(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"] ?? "http://localhost:4317");
        }));

Usa el código con precaución.
3. ¿Cómo analizar las trazas?

    Ejecuta docker-compose up -d.
    Realiza un par de peticiones a tu API (ej. crear una tarea).
    Abre tu navegador en http://localhost:16686.
    Selecciona el servicio "TodoMicroservice" y haz clic en "Find Traces".

Verás una línea de tiempo donde cada "barra" representa una operación. Si una consulta a SQL Server es lenta, Jaeger la marcará claramente, permitiéndote diagnosticar problemas de rendimiento en segundos.
Este es el flujo completo de un microservicio profesional. ¿Quieres que veamos cómo implementar Pruebas de Integración para asegurar que todo este flujo (API -> Validador -> Repositorio -> DB) funciona correctamente?

---

## Quiero ver como implementar Pruebas de Integracion

Para implementar
Pruebas de Integración en .NET de forma profesional, utilizaremos WebApplicationFactory. Esto permite levantar tu microservicio completo en memoria (incluyendo el pipeline de middleware, validaciones y servicios) para probarlo como lo haría un cliente real.
1. Instalación de Paquetes
En tu proyecto de pruebas (xUnit), añade:
bash

dotnet add package Microsoft.AspNetCore.Mvc.Testing
dotnet add package Microsoft.EntityFrameworkCore.InMemory # Para no ensuciar la DB real

Usa el código con precaución.
2. Configurar la Factoría de Pruebas
Creamos una clase para configurar un entorno de prueba controlado, sustituyendo la base de datos real por una en memoria:
csharp

public class TodoApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services => {
            // Eliminar la configuración real de SQL Server
            var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<TodoContext>));
            if (descriptor != null) services.Remove(descriptor);

            // Añadir base de datos en memoria para los tests
            services.AddDbContext<TodoContext>(options => options.UseInMemoryDatabase("TestDb"));
        });
    }
}

Usa el código con precaución.
3. Escribir el Test de Integración
Probamos el flujo completo: desde el envío del JSON, pasando por el Filtro de Validación, el Middleware y el Repositorio.
csharp

public class TodoIntegrationTests : IClassFixture<TodoApiFactory>
{
    private readonly HttpClient _client;

    public TodoIntegrationTests(TodoApiFactory factory) => _client = factory.CreateClient();

    [Fact]
    public async Task PostTodo_WithValidData_ReturnsCreated()
    {
        // Arrange
        var request = new CreateTodoRequest("Comprar pan", DateTime.Now.AddDays(1));

        // Act
        var response = await _client.PostAsJsonAsync("/api/todo", request);

        // Assert
        response.EnsureSuccessStatusCode();
        var todo = await response.Content.ReadFromJsonAsync<TodoResponse>();
        Assert.Equal("Comprar pan", todo.Title);
    }

    [Fact]
    public async Task PostTodo_WithShortTitle_ReturnsBadRequest_AndDetailedErrors()
    {
        // Arrange (Título de 1 caracter, falla validación)
        var request = new CreateTodoRequest("A", DateTime.Now.AddDays(1));

        // Act
        var response = await _client.PostAsJsonAsync("/api/todo", request);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        
        // Verificamos que el Middleware devolvió el formato esperado
        var errorContent = await response.Content.ReadAsStringAsync();
        Assert.Contains("El título debe tener al menos 3 caracteres", errorContent);
    }
}

Usa el código con precaución.
Por qué estas pruebas son fundamentales:

    Validación del Pipeline: Verificas que tu ValidationFilter y Middleware están correctamente registrados y funcionan.
    Cero Falsos Positivos: A diferencia de los Unit Tests, aquí pruebas que la Inyección de Dependencias está bien configurada.
    Velocidad: Al usar InMemoryDatabase y TestServer, los tests se ejecutan en milisegundos sin necesidad de levantar contenedores de Docker.

Recursos adicionales
Para pruebas aún más robustas, puedes explorar Testcontainers for .NET, que permite levantar un SQL Server real en Docker solo durante la ejecución de los tests.
¿Te gustaría ver cómo automatizar la ejecución de estos tests mediante un Pipeline de GitHub Actions antes de desplegar tu microservicio?

---

## Me gustaría ver un pipeline para github

Para automatizar tus tests,
crearemos un Workflow en GitHub Actions. Este pipeline se activará con cada push o pull_request, asegurando que nadie suba código que rompa la validación, el repositorio o el contrato del microservicio.
1. Crear el archivo del Workflow
Crea el archivo en tu repositorio en la ruta: .github/workflows/dotnet-ci.yml.
yaml

name: Microservice CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout del código
      uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '8.0.x'

    - name: Restaurar dependencias
      run: dotnet restore

    - name: Compilar (Build)
      run: dotnet build --no-restore -c Release

    - name: Ejecutar Tests de Integración
      run: dotnet test --no-build -c Release --verbosity normal

Usa el código con precaución.
2. Puntos clave del Pipeline

    dotnet restore: Descarga todos los paquetes de NuGet (incluyendo FluentValidation y OpenTelemetry).
    dotnet test: Ejecuta los tests de integración que creamos con WebApplicationFactory. Si un test falla (por ejemplo, si alguien deshabilita el middleware de validación), el pipeline se marcará en rojo y bloqueará el merge.
    Seguridad: Al usar ubuntu-latest, GitHub proporciona un entorno limpio y aislado para cada ejecución.

3. Buenas prácticas en el Pipeline

    Caché: Para acelerar los flujos, puedes añadir el paso Cache de NuGet para evitar descargar las librerías en cada ejecución.
    Reportes: Puedes configurar el pipeline para que publique los resultados de los tests en la pestaña "Actions" de GitHub usando vstest-reporter.

Resumen del Ecosistema Construido
Hasta ahora tienes un microservicio con:

    Arquitectura Limpia (Repository Pattern).
    Validación Automática (FluentValidation + Action Filters).
    Manejo Global de Errores (Middleware).
    Observabilidad Estándar (OpenTelemetry + Jaeger).
    Contenedores Profesionales (Docker Multi-stage + Compose).
    Calidad Asegurada (Tests de Integración + CI/CD).

¿Deseas que terminemos este ciclo configurando el despliegue automático (CD) hacia un registro de contenedores (como Docker Hub o Azure Container Registry) o prefieres profundizar en la seguridad con JWT?

---

## Me gustaria tener Continuous Delivery

Para configurar la
Entrega Continua (CD) hacia el GitHub Container Registry (GHCR), ampliaremos tu workflow de GitHub Actions. El objetivo es que, tras superar los tests, se construya la imagen de Docker y se publique automáticamente bajo tu cuenta de GitHub.
1. Actualización del Workflow (.github/workflows/dotnet-ci.yml)
Añadiremos un nuevo job llamado deploy que se ejecute solo si los tests pasan correctamente en la rama main.
yaml

name: Microservice CI/CD

on:
  push:
    branches: [ main ]

# Permisos necesarios para escribir en el registro de paquetes de GitHub
permissions:
  contents: read
  packages: write

jobs:
  build-and-test:
    # ... (mismo contenido que el paso anterior) ...

  publish-docker:
    needs: build-and-test # Solo se ejecuta si los tests pasan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout del código
        uses: actions/checkout@v4

      - name: Login en GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extraer metadatos (Tags, Labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=sha,format=short
            latest

      - name: Construir y Push de la imagen Docker
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ id.meta.outputs.tags }}
          labels: ${{ id.meta.outputs.labels }}

Usa el código con precaución.
2. Puntos Clave de la Configuración

    GITHUB_TOKEN: GitHub genera este secreto automáticamente. No necesitas configurar nada manualmente en los Secrets del repo para que el push funcione en GitHub Container Registry.
    docker/metadata-action: Genera automáticamente etiquetas inteligentes. Tu imagen tendrá el tag latest y el tag del commit sha, lo cual es vital para el versionado y el rollback.
    needs: build-and-test: Esto crea una barrera de calidad. Si alguien rompe un test de integración, la imagen no se publica, manteniendo el registro de contenedores siempre con código estable.

3. ¿Cómo usar tu nueva imagen?
Una vez que el pipeline termine (en verde), tu imagen estará disponible en ghcr.io/tu-usuario/nombre-del-repo:latest. Podrás desplegarla en cualquier VPS o nube simplemente con:
bash

docker pull ghcr.io/tu-usuario/nombre-del-repo:latest

Usa el código con precaución.
4. Ciclo de Vida Completo
Con esto, hemos cerrado el círculo:

    Código: C# 12, Records, Clean API.
    Calidad: Validaciones, Repositorios, Middleware.
    Monitoreo: OpenTelemetry + Jaeger.
    Infraestructura: Docker + Compose.
    Automatización: CI/CD completo en GitHub.

¿Te gustaría ver cómo añadir un Paso de Despliegue final (por ejemplo, actualizar automáticamente un servicio en un VPS vía SSH) o prefieres proteger esta infraestructura implementando Autenticación JWT?

---

## Quiero proteger la infrastructura con autenticacion con JWT

Para proteger tu microservicio, implementaremos
Autenticación JWT (JSON Web Tokens). Esto asegura que solo los clientes con un token válido puedan interactuar con los endpoints de tu lista de tareas.
1. Instalación del Paquete
Añade el soporte para Bearer Authentication desde NuGet:
bash

dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer

Usa el código con precaución.
2. Configuración en Program.cs
Debes registrar el servicio de autenticación y definir los parámetros de validación del token:
csharp

using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// El orden es crítico: Autenticación ANTES de Autorización
app.UseAuthentication(); 
app.UseAuthorization();

app.MapControllers();
app.Run();

Usa el código con precaución.
3. Proteger los Endpoints
Ahora puedes usar el atributo [Authorize] en tu controlador. Gracias al Patrón Repository, la lógica de seguridad está separada de la persistencia:
csharp

[ApiController]
[Route("api/[controller]")]
[Authorize] // Protege todos los métodos de este controlador
public class TodoController : ControllerBase 
{
    private readonly ITodoRepository _repository;
    public TodoController(ITodoRepository repository) => _repository = repository;

    [HttpGet]
    public async Task<ActionResult<IEnumerable<TodoResponse>>> GetTodos() 
    {
        // Podemos obtener el ID del usuario directamente del Token
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        
        var todos = await _repository.GetAllAsync(); // Idealmente filtrar por userId
        return Ok(todos.Select(t => new TodoResponse(t.Id, t.Title, t.IsCompleted)));
    }
}

Usa el código con precaución.
4. Configuración de Secretos (appsettings.json)
Añade las claves necesarias. En producción, usa GitHub Secrets o Azure Key Vault:
json

{
  "Jwt": {
    "Key": "UnaClaveSuperSecretaYMuyLargaDeAlMenos32Chars",
    "Issuer": "tu-microservicio",
    "Audience": "tus-usuarios"
  }
}

Usa el código con precaución.
5. Impacto en la Observabilidad y Tests

    OpenTelemetry: Las trazas ahora incluirán información sobre si la petición fue autenticada o rechazada (401 Unauthorized).
    Tests de Integración: Deberás actualizar tus tests para generar un token de prueba o usar un Mock de Claims para simular un usuario logueado.

¿Te gustaría ver cómo crear un servicio de generación de tokens para que los usuarios puedan hacer login, o prefieres ver cómo inyectar automáticamente el token en la interfaz de Swagger para probar los endpoints protegidos?

---

## Quiero ver como inyectar el token JWT para probar los endpoints

Para que puedas probar tus endpoints protegidos sin salir de la interfaz de
Swagger, necesitamos configurar un "Candado" de seguridad. Esto permitirá que pegues tu token una vez y Swagger lo envíe automáticamente en el encabezado Authorization: Bearer <token> de cada petición.
1. Configuración de Swagger en Program.cs
Modifica el método AddSwaggerGen para definir el esquema de seguridad Bearer:
csharp

using Microsoft.OpenApi.Models;

builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Todo API", Version = "v1" });

    // 1. Definir el esquema de seguridad
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Ingresa el token JWT así: Bearer {tu_token}"
    });

    // 2. Aplicar el esquema de forma global
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

Usa el código con precaución.
2. Cómo usarlo en la UI de Swagger

    Ejecuta tu microservicio (o el docker-compose up).
    Abre la URL de Swagger (usualmente http://localhost:5000/swagger).
    Verás un botón nuevo llamado "Authorize" en la parte superior derecha.
    Haz clic en él y escribe: Bearer <tu_token_aqui>.
    Haz clic en Authorize y luego en Close.

Ahora, cualquier botón de "Try it out" enviará el token en los headers y el controlador te permitirá pasar el filtro de [Authorize].
3. Tip Pro: Integración con OpenTelemetry
Cuando el token es inválido o falta, OpenTelemetry capturará automáticamente el error 401 Unauthorized. Podrás ver en Jaeger exactamente cuánto tiempo pasó el sistema validando el token antes de rechazar la solicitud.
Resumen del Microservicio Profesional
Has construido un sistema extremadamente robusto que sigue los estándares de Microsoft Architecture:

    Seguridad: JWT con Swagger UI.
    Arquitectura: Repository + DTOs (Records).
    Calidad: Validación automática + Middleware global + Tests CI/CD.
    DevOps: Docker Multi-stage + Compose + GHCR.
    Observabilidad: OpenTelemetry + Jaeger + Serilog.

¿Te gustaría que implementemos un Endpoint de Login básico que genere estos tokens para que puedas completar el flujo de pruebas, o prefieres ver cómo gestionar el Versionado de la API (v1, v2) para no romper el contrato con tus clientes?

---

## Implementemos un endpoin de Login básico

Para completar el sistema, necesitamos un servicio que emita los tokens. Crearemos un
AuthService que valide credenciales (en este caso, un usuario "demo" para simplificar) y genere el JWT.
1. El DTO de Login (Record)
csharp

public record LoginRequest(string Username, string Password);
public record AuthResponse(string Token, DateTime Expiration);

Usa el código con precaución.
2. Implementación del Servicio de Tokens
Este servicio encapsula la lógica criptográfica de Microsoft IdentityModel.
csharp

public interface IAuthService {
    AuthResponse? Authenticate(LoginRequest request);
}

public class AuthService : IAuthService {
    private readonly IConfiguration _config;
    public AuthService(IConfiguration config) => _config = config;

    public AuthResponse? Authenticate(LoginRequest request) {
        // Validación dummy para el prototipo
        if (request.Username != "admin" || request.Password != "P@ssw0rd123") return null;

        var claims = new[] {
            new Claim(ClaimTypes.Name, request.Username),
            new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
            new Claim(ClaimTypes.Role, "Admin")
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expiration = DateTime.UtcNow.AddHours(2);

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: expiration,
            signingCredentials: creds
        );

        return new AuthResponse(new JwtSecurityTokenHandler().WriteToken(token), expiration);
    }
}

Usa el código con precaución.
3. El Controlador de Autenticación
Creamos un controlador ligero que use nuestro nuevo servicio:
csharp

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase {
    private readonly IAuthService _authService;
    public AuthController(IAuthService authService) => _authService = authService;

    [HttpPost("login")]
    public IActionResult Login(LoginRequest request) {
        var response = _authService.Authenticate(request);
        if (response == null) return Unauthorized(new { Message = "Credenciales inválidas" });
        
        return Ok(response);
    }
}

Usa el código con precaución.
4. Registro de Dependencias
En el Program.cs, registra el servicio:
csharp

builder.Services.AddScoped<IAuthService, AuthService>();

Usa el código con precaución.
Flujo de Prueba Completo

    Levanta el sistema con docker-compose up.
    Obtén el Token: Ve a Swagger, usa el endpoint /api/auth/login con las credenciales admin / P@ssw0rd123.
    Autoriza: Copia el token del JSON de respuesta, pulsa el botón Authorize de Swagger y pégalo.
    Usa la API: Ahora los endpoints de /api/todo te devolverán un 200 OK en lugar de un 401 Unauthorized.

Detalles de Arquitectura Microservicios
En un ecosistema real, este AuthController podría vivir en un microservicio independiente llamado Identity Service. Al usar JWT, el microservicio de Tareas no necesita consultar a la base de datos de usuarios para validar el token; simplemente verifica la firma digital del mismo con la clave compartida.
¿Te gustaría ver cómo implementar Roles y Políticas (ej: que solo un "Admin" pueda borrar tareas) o prefieres profundizar en el Versionado de la API?

---

## Veamos como implementar Roles y Politicas

Pensando
Para implementar seguridad basada en
Roles y Políticas, aprovecharemos el sistema de Claims (notificaciones) que ya incluimos en tu JWT. Esto permite restringir acciones sensibles (como borrar una tarea) solo a usuarios con privilegios específicos.
1. Definir la Política en Program.cs
En lugar de solo pedir que el usuario esté autenticado, definimos qué requisitos debe cumplir.
csharp

builder.Services.AddAuthorization(options =>
{
    // Política simple basada en rol
    options.AddPolicy("AdminOnly", policy => policy.RequireRole("Admin"));
    
    // Política personalizada (ej: usuarios con nivel de suscripción 'Pro')
    options.AddPolicy("ProFeature", policy => policy.RequireClaim("SubscriptionLevel", "Pro"));
});

Usa el código con precaución.
2. Aplicar la Política en el Controlador
Ahora usamos el atributo [Authorize] especificando la política o el rol directamente.
csharp

[ApiController]
[Route("api/[controller]")]
[Authorize] // Requiere estar logueado para todo el controlador
public class TodoController : ControllerBase 
{
    private readonly ITodoRepository _repository;
    public TodoController(ITodoRepository repository) => _repository = repository;

    [HttpDelete("{id}")]
    [Authorize(Policy = "AdminOnly")] // Solo usuarios con rol 'Admin' pueden borrar
    public async Task<IActionResult> DeleteTodo(int id) 
    {
        // Lógica de eliminación...
        return NoContent();
    }
}

Usa el código con precaución.
3. Actualizar el Generador de Tokens (AuthService)
Para que esto funcione, el token debe incluir el claim de rol. Refactorizamos el AuthService que creamos antes:
csharp

var claims = new List<Claim> {
    new Claim(ClaimTypes.Name, request.Username),
    new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
    // Agregamos el rol dinámicamente
    new Claim(ClaimTypes.Role, request.Username == "admin" ? "Admin" : "User")
};

Usa el código con precaución.
4. Integración con Swagger
Lo mejor de haber configurado el "Candado" de Swagger anteriormente es que, si intentas usar el método DELETE con un token que no tiene el rol Admin, la interfaz te mostrará automáticamente un error 403 Forbidden.
Beneficios en Microservicios

    Desacoplamiento: El microservicio de "Tareas" no pregunta a una base de datos quién es el usuario; confía ciegamente en los Roles que vienen firmados dentro del JWT.
    Granularidad: Puedes crear políticas complejas que combinen múltiples factores (roles, antigüedad del usuario, país, etc.) sin ensuciar la lógica de tus métodos.

¿Te gustaría implementar un Middleware de Autorización Personalizado para lógica más compleja o prefieres pasar al Versionado de la API para manejar cambios disruptivos en el futuro?

---

## Implementar MIddleware de Autorización

Para implementar un sistema de
Permisos Dinámicos, lo más eficiente en .NET no es un Middleware tradicional, sino el uso de Requerimientos y Manejadores de Políticas (Requirement Handlers). Esto permite definir permisos granulares (como Task.Read, Task.Delete) que se asocian a los roles y se validan automáticamente.
1. Definir el Atributo de Permisos
Usaremos un atributo personalizado para que sea fácil de leer en los controladores:
csharp

public class HasPermissionAttribute : AuthorizeAttribute
{
    public HasPermissionAttribute(string permission) : base(permission) { }
}

Usa el código con precaución.
2. Crear el Requerimiento y el Manejador (Handler)
Aquí es donde ocurre la "magia" de combinar permisos. El Handler intercepta la petición, lee los roles del JWT y verifica si alguno tiene el permiso necesario.
csharp

public class PermissionRequirement : IAuthorizationRequirement
{
    public string Permission { get; }
    public PermissionRequirement(string permission) => Permission = permission;
}

public class PermissionHandler : AuthorizationHandler<PermissionRequirement>
{
    // Simulación de una DB de roles/permisos. En producción, usa caché o DB.
    private readonly Dictionary<string, string[]> _rolePermissions = new() {
        { "Admin", new[] { "Task.Read", "Task.Write", "Task.Delete" } },
        { "Editor", new[] { "Task.Read", "Task.Write" } },
        { "User", new[] { "Task.Read" } }
    };

    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, PermissionRequirement requirement)
    {
        // Obtener todos los roles del usuario desde los Claims del JWT
        var userRoles = context.User.FindAll(ClaimTypes.Role).Select(r => r.Value);

        // Combinar permisos de todos los roles que tenga el usuario
        var permissions = userRoles.SelectMany(role => 
            _rolePermissions.TryGetValue(role, out var p) ? p : Array.Empty<string>());

        if (permissions.Contains(requirement.Permission))
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}

Usa el código con precaución.
3. El Policy Provider (Para evitar registrar cada permiso a mano)
Este componente genera políticas "al vuelo" cuando ve el atributo HasPermission.
csharp

public class PermissionPolicyProvider : DefaultAuthorizationPolicyProvider
{
    public PermissionPolicyProvider(IOptions<AuthorizationOptions> options) : base(options) { }

    public override async Task<AuthorizationPolicy?> GetPolicyAsync(string policyName)
    {
        var policy = await base.GetPolicyAsync(policyName);
        if (policy != null) return policy;

        return new AuthorizationPolicyBuilder()
            .AddRequirements(new PermissionRequirement(policyName))
            .Build();
    }
}

Usa el código con precaución.
4. Registro en Program.cs
Registramos el proveedor y el manejador para que el pipeline de seguridad los utilice:
csharp

builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();
builder.Services.AddScoped<IAuthorizationHandler, PermissionHandler>();

Usa el código con precaución.
5. Uso en el Controlador
Ahora puedes ser tan específico como necesites. Si un usuario tiene los roles "Editor" y "Auditor", sus permisos se sumarán automáticamente.
csharp

[ApiController]
[Route("api/[controller]")]
public class TodoController : ControllerBase
{
    [HttpGet]
    [HasPermission("Task.Read")]
    public IActionResult Get() => Ok("Lectura permitida");

    [HttpDelete("{id}")]
    [HasPermission("Task.Delete")]
    public IActionResult Delete(int id) => Ok($"Tarea {id} borrada");
}

Usa el código con precaución.
¿Por qué este enfoque es superior a un Middleware?

    Suma de permisos: Si el usuario tiene múltiples roles, el SelectMany combina todos sus permisos de forma transparente.
    Integración con ASP.NET Core Authorization: Al usar el sistema nativo de políticas, obtienes compatibilidad automática con los desafíos 401 y 403.
    Escalabilidad: Puedes mover el diccionario _rolePermissions a una base de datos o un Redis Cache sin cambiar el código de tus controladores.

¿Te gustaría que añadamos un paso de Auditoría en el Logger de Serilog para registrar quién intentó usar un permiso que no tenía, o prefieres ver el Versionado de la API?

---

## Veamos como añadir un paso de Auditoria

Para implementar una
Auditoría de Seguridad profesional, aprovecharemos el sistema de Middleware y el Log Estructurado de Serilog. Esto nos permitirá registrar no solo quién hizo qué, sino también capturar los intentos fallidos de acceso por falta de permisos, algo vital para detectar ataques de fuerza bruta o escalada de privilegios.
1. Enriquecer el Middleware de Excepciones
Modificaremos nuestro middleware para que, cuando el sistema de políticas deniegue el acceso (403), se genere un log con el contexto completo del usuario.
csharp

// En el Middleware de Excepciones/Seguridad
public async Task InvokeAsync(HttpContext context)
{
    await _next(context);

    // Capturar cuando el framework de seguridad marca un 403 (Forbidden)
    if (context.Response.StatusCode == StatusCodes.Status403Forbidden)
    {
        var user = context.User.Identity?.Name ?? "Anónimo";
        var path = context.Request.Path;
        var method = context.Request.Method;
        var permissionsRequired = context.GetEndpoint()?.Metadata.GetMetadata<HasPermissionAttribute>()?.Policy;

        // Log Estructurado para herramientas como Elasticsearch/Seq
        _logger.LogWarning("ACCESO DENEGADO: El usuario {User} intentó realizar {Method} en {Path} sin el permiso {Permission}", 
            user, method, path, permissionsRequired);
    }
}

Usa el código con precaución.
2. Auditoría de Operaciones Exitosas
Para las acciones que sí se permiten, lo ideal es usar un Action Filter de auditoría que registre los cambios en la base de datos:
csharp

public class AuditFilter : IAsyncActionFilter
{
    private readonly ILogger<AuditFilter> _logger;

    public AuditFilter(ILogger<AuditFilter> logger) => _logger = logger;

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        // Antes de la ejecución (Capturar datos de entrada)
        var user = context.HttpContext.User.Identity?.Name ?? "Anónimo";
        var action = context.ActionDescriptor.DisplayName;

        var result = await next(); // Ejecutar el controlador

        // Después de la ejecución (Solo si fue exitosa)
        if (context.HttpContext.Response.StatusCode >= 200 && context.HttpContext.Response.StatusCode < 300)
        {
            _logger.LogInformation("AUDITORÍA: Usuario {User} ejecutó con éxito {Action}", user, action);
        }
    }
}

Usa el código con precaución.
3. Registro Global en Program.cs
Para que la auditoría sea automática en todos tus microservicios, registra el filtro globalmente:
csharp

builder.Services.AddControllers(options => 
{
    options.Filters.Add<AuditFilter>();
});

Usa el código con precaución.
4. Visualización en la Traza de Jaeger
Como configuramos OpenTelemetry, podemos añadir estos eventos de auditoría directamente al Span de la petición. Así, en Jaeger verás una línea de tiempo que dice: "10:05:01 - Intento de borrado - Usuario: Admin - Resultado: Éxito".
csharp

// Dentro del Filter o Middleware
var activity = Activity.Current;
activity?.AddEvent(new ActivityEvent("AuditTrail", tags: new ActivityTagsCollection {
    { "user", user },
    { "action", action },
    { "status", "success" }
}));

Usa el código con precaución.
Beneficios de este enfoque

    Cumplimiento (Compliance): Cumples con normativas como GDPR o SOC2 al tener un registro inalterable de quién accede a los datos.
    Forense: Si ocurre un incidente, puedes filtrar en tus logs todos los "ACCESO DENEGADO" de una IP o usuario específico.
    Rendimiento: Al usar logs asíncronos con Serilog, la auditoría no ralentiza la respuesta al cliente.

¿Te gustaría ver cómo Versionar tu API para que estos cambios de permisos no afecten a clientes antiguos, o prefieres configurar un Dashboard en Grafana para visualizar estos logs de auditoría?

---

## Veamos el versionado de la API

Para manejar cambios disruptivos en microservicios, el estándar en .NET es el
API Versioning. Esto permite que la v1 (con permisos simples) y la v2 (con el sistema complejo de permisos y auditoría) coexistan sin romper las aplicaciones de tus clientes.
1. Instalación de paquetes
Añade las librerías oficiales de ASP.NET Core API Versioning:
bash

dotnet add package Asp.Versioning.Mvc
dotnet add package Asp.Versioning.Mvc.ApiExplorer

Usa el código con precaución.
2. Configuración en Program.cs
Configuramos el sistema para que detecte la versión a través de la URL (ej: /v1/todo) o de un Header (ej: x-api-version: 2.0).
csharp

using Asp.Versioning;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true; // Agrega 'api-supported-versions' al header de respuesta
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new HeaderApiVersionReader("x-api-version")
    );
}).AddApiExplorer(options => {
    options.GroupNameFormat = "'v'VVV"; // Formato v1, v2.1, etc.
    options.SubstituteApiVersionInUrl = true;
});

Usa el código con precaución.
3. Implementación en los Controladores
Podemos tener dos versiones del mismo controlador viviendo en carpetas separadas:
Versión 1 (Legada):
csharp

[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/[controller]")]
public class TodoController : ControllerBase {
    // Lógica antigua...
}

Usa el código con precaución.
Versión 2 (Nueva con Auditoría y Permisos complejos):
csharp

[ApiVersion("2.0")]
[Route("api/v{version:apiVersion}/[controller]")]
public class TodoController : ControllerBase {
    [HasPermission("Task.Delete")]
    [HttpDelete("{id}")]
    public IActionResult DeleteV2(int id) => Ok("Borrado con lógica V2");
}

Usa el código con precaución.
4. Swagger con soporte Multiversión
Para que Swagger muestre un desplegable con las versiones disponibles, necesitamos configurar los SwaggerDoc dinámicamente:
csharp

builder.Services.AddSwaggerGen(options => {
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Todo API", Version = "v1" });
    options.SwaggerDoc("v2", new OpenApiInfo { Title = "Todo API", Version = "v2" });
    // Reutiliza la configuración de seguridad JWT que hicimos antes...
});

// En el pipeline:
app.UseSwaggerUI(options => {
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "V1");
    options.SwaggerEndpoint("/swagger/v2/swagger.json", "V2");
});

Usa el código con precaución.
Ventajas del Versionado

    Contratos Inmutables: Los clientes que usan la v1 no sufrirán errores si cambias el formato del JSON en la v2.
    Deprecación Gradual: Puedes marcar versiones como obsoletas usando [ApiVersion("1.0", Deprecated = true)].
    Observabilidad Segregada: En Jaeger y Serilog, ahora verás qué versión de la API es la más utilizada o cuál está generando más errores.

Con esto, tu microservicio está listo para evolucionar en producción. ¿Te gustaría ver cómo implementar Resiliencia y Retries con Polly para cuando la base de datos no responda, o prefieres configurar un Dashboard en Grafana para monitorear todo lo que hemos construido?
¿Por cuál de estos dos pilares finales te gustaría continuar?

---

## Configurar un Dashboard en Grafana

Para tener un dashboard en
Grafana, necesitas una base de datos de métricas, y Prometheus es el estándar absoluto para esto.
En el ecosistema .NET, el flujo funciona así:

    Tu App: Expone métricas (CPU, RAM, peticiones por segundo, errores 403).
    Prometheus: Pasa cada X segundos y "raspa" (scrapes) esos datos.
    Grafana: Se conecta a Prometheus y dibuja los gráficos bonitos.

Aquí tienes cómo montarlo:
1. Preparar la App (Exponer Métricas)
Instala el paquete de exportación de métricas para OpenTelemetry:
bash

dotnet add package OpenTelemetry.Exporter.Prometheus.AspNetCore

Usa el código con precaución.
Luego, en tu Program.cs, añade el endpoint de métricas:
csharp

builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddRuntimeInstrumentation() // Métricas de GC, CPU, hilos de .NET
        .AddPrometheusExporter()); // Expone el endpoint /metrics

var app = builder.Build();

// Publica las métricas para que Prometheus las lea
app.MapPrometheusScrapingEndpoint(); 

Usa el código con precaución.
2. Configurar el "Stack" en Docker Compose
Actualiza tu docker-compose.yml para incluir a los nuevos protagonistas:
yaml

services:
  # ... (tus servicios anteriores: api, db, jaeger) ...

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - prometheus

Usa el código con precaución.
3. Configurar Prometheus (prometheus.yml)
Crea este archivo en la raíz para decirle a Prometheus dónde está tu API:
yaml

scrape_configs:
  - job_name: 'todo-api'
    scrape_interval: 5s
    static_configs:
      - targets: ['todo-api:8080'] # El nombre del servicio en el compose

Usa el código con precaución.
4. ¿Qué verás en Grafana?

    Entra a http://localhost:3000 (user: admin / pass: admin).
    Añade un Data Source de tipo Prometheus con la URL http://prometheus:9090.
    Importa un Dashboard: No lo crees desde cero. Usa el ID 19924 (o busca "ASP.NET Core Observability") y verás instantáneamente:
        Tasa de errores (4xx, 5xx).
        Tiempo medio de respuesta de tus controladores.
        Uso de memoria del contenedor Docker.

El Círculo Completo de Observabilidad
Ahora tienes las "Tres Señales Doradas":

    Logs: Con Serilog (¿Qué pasó?).
    Traces: Con Jaeger (¿Dónde se tardó?).
    Metrics: Con Prometheus/Grafana (¿Cómo está la salud del sistema ahora?).

¿Te gustaría que veamos cómo configurar una Alerta en Grafana para que te avise (por Slack o Email) si los errores 403 (de auditoría) suben repentinamente, o pasamos a la Resiliencia con Polly?

---

## Veamos como establecer una alerta en grafana

Para configurar una alerta en
Grafana, utilizaremos el Grafana Alerting. En nuestro caso, crearemos una alerta que se dispare si los intentos fallidos de autorización (403 Forbidden) superan un umbral, lo que podría indicar un ataque o un error de configuración en los permisos. 
1. Definir la consulta (Query)
En la interfaz de Grafana (localhost:3000):

    Ve a Alerting > Alert rules > Create alert rule.
    Ponle un nombre: Demasiados Accesos Denegados (403).
    Selecciona tu Data Source de Prometheus.
    Define la métrica usando PromQL:
    promql

    sum(rate(http_server_request_duration_seconds_count{http_response_status_code="403"}[1m]))

    Usa el código con precaución.

Esto mide la tasa de errores 403 por segundo en el último minuto. 

2. Establecer la Condición

    En Threshold, define que la alerta se active si el valor es IS ABOVE (está por encima de) 0.5 (ajusta según tu tráfico).
    En Evaluate every, pon 10s para que Grafana revise la métrica constantemente.

3. Configurar el Punto de Contacto (Contact Point)
Para que la alerta llegue a algún sitio, ve a Alerting > Contact points:

    Haz clic en Add contact point.
    Elige el canal: Slack, Discord, Email o incluso Webhook (si quieres que otro microservicio reaccione).
    Si usas Slack, pega la URL de tu Webhook y haz un Test. 

4. Enriquecer el mensaje de Alerta
Puedes usar plantillas para que el mensaje incluya detalles de la auditoría que configuramos:
text

⚠️ Alerta de Seguridad en Microservicio: {{ $labels.service }}
Se han detectado múltiples intentos de acceso denegado (403).
Valor actual: {{ $values.B.Value }} req/seg.

Usa el código con precaución.
5. ¿Cómo probar la Alerta?
Simplemente intenta acceder a un endpoint de tu API con un token que no tenga los permisos necesarios repetidamente.

    Prometheus detectará el pico de errores 403.
    Grafana cambiará el estado de la alerta de Normal a Pending y luego a Firing.
    Recibirás la notificación en tu canal configurado.

Beneficios del Alerting Proactivo

    Detección de ataques: Identificas intentos de escalada de privilegios en tiempo real.
    Reducción de MTTR: (Mean Time To Repair). Te enteras del problema antes que el cliente.

---

## Resiliencia con Polly

Para cerrar con broche de oro, implementaremos
Polly, la librería de resiliencia estándar en .NET. En un entorno de microservicios, la red fallará y las bases de datos tendrán picos de latencia. Polly permite que tu código "aguante los golpes" sin romperse.
1. Instalación
Añade el paquete para integración con el cliente HTTP o servicios:
bash

dotnet add package Microsoft.Extensions.Http.Polly

Usa el código con precaución.
2. Configurar una Estrategia de Resiliencia
En .NET 8+, la forma recomendada es usar el Resilience Pipeline. Vamos a crear una estrategia combinada de Retry (Reintento) y Circuit Breaker (Disyuntor) en tu Program.cs.
csharp

using Polly;
using Polly.CircuitBreaker;

builder.Services.AddResiliencePipeline("default", pipeline =>
{
    pipeline.AddRetry(new()
    {
        ShouldHandle = new PredicateBuilder().Handle<Exception>(),
        MaxRetryAttempts = 3,
        Delay = TimeSpan.FromSeconds(2),
        BackoffType = DelayBackoffType.Exponential // 2s, 4s, 8s...
    })
    .AddCircuitBreaker(new()
    {
        ShouldHandle = new PredicateBuilder().Handle<Exception>(),
        Threshold = 0.5, // Si el 50% de las llamadas fallan...
        SamplingDuration = TimeSpan.FromSeconds(30),
        MinimumThroughput = 5,
        BreakDuration = TimeSpan.FromSeconds(15) // ...abre el circuito 15s
    });
});

Usa el código con precaución.
3. Aplicar Resiliencia en el Repositorio
Ahora, protegemos las llamadas a la base de datos o servicios externos inyectando el ResiliencePipelineProvider.
csharp

public class TodoRepository : ITodoRepository 
{
    private readonly TodoContext _context;
    private readonly ResiliencePipeline _pipeline;

    public TodoRepository(TodoContext context, ResiliencePipelineProvider<string> pipelineProvider)
    {
        _context = context;
        _pipeline = pipelineProvider.GetPipeline("default");
    }

    public async Task<IEnumerable<TodoItem>> GetAllAsync()
    {
        // El pipeline ejecutará la lógica y reintentará automáticamente si falla
        return await _pipeline.ExecuteAsync(async token => 
            await _context.TodoItems.ToListAsync(token));
    }
}

Usa el código con precaución.
4. Integración con Observabilidad
Lo mejor de Polly es que se integra perfectamente con lo que ya construimos:

    OpenTelemetry: Verás los reintentos como "intentos" adicionales dentro de la misma traza en Jaeger.
    Métricas: Puedes exponer cuántas veces se activó el Circuit Breaker hacia Prometheus.
    Logs: Serilog registrará cada reintento, dándote visibilidad de si la base de datos está inestable.

¿Por qué estas dos estrategias?

    Retry: Ideal para fallos transitorios (un micro-corte de red).
    Circuit Breaker: Evita que tu sistema sature a un servicio que ya está caído, dándole tiempo a recuperarse y devolviendo un error rápido al usuario en lugar de dejarlo esperando.

Conclusión del Prototipo Profesional
Has diseñado un microservicio que no solo cumple su función, sino que es resistente a fallos, auditable, observable, seguro y automatizado.
¿Te gustaría que generemos un documento resumen (README) con toda esta arquitectura para tu repositorio, o quieres ver cómo implementar el Patrón Outbox para asegurar que los mensajes se envíen incluso si la DB falla?
Propongo generar el README final para consolidar todo el conocimiento. ¿Te parece bien?

---

## Vamos a implementar el patron Outbox

El
Patrón Outbox es esencial en microservicios para garantizar la consistencia eventual. Resuelve el problema de: "¿Qué pasa si guardo la tarea en la DB, pero el mensaje para el servicio de notificaciones no se envía porque el Message Broker (RabbitMQ/Azure Service Bus) está caído?".
En lugar de enviar el mensaje directamente, lo guardamos en la misma transacción de la base de datos que la tarea.
1. Crear la Entidad OutboxMessage
Esta tabla vivirá en tu base de datos de Tareas.
csharp

public class OutboxMessage {
    public Guid Id { get; set; }
    public string Type { get; set; } = string.Empty; // Ej: "TodoCreated"
    public string Content { get; set; } = string.Empty; // JSON del mensaje
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? ProcessedAtUtc { get; set; } // Nulo hasta que se envíe
}

Usa el código con precaución.
2. Refactorizar el Repositorio (Transaccional)
Ahora, al crear una tarea, guardamos el mensaje en la tabla Outbox dentro de la misma transacción.
csharp

public async Task CreateTodoAsync(TodoItem item) {
    using var transaction = await _context.Database.BeginTransactionAsync();
    
    try {
        // 1. Guardar la tarea
        _context.TodoItems.Add(item);

        // 2. Crear el mensaje Outbox
        var message = new OutboxMessage {
            Id = Guid.NewGuid(),
            Type = "TodoCreatedEvent",
            Content = JsonSerializer.Serialize(new { item.Id, item.Title }),
            CreatedAtUtc = DateTime.UtcNow
        };
        _context.Set<OutboxMessage>().Add(message);

        // 3. Commit de ambos (Atómico)
        await _context.SaveChangesAsync();
        await transaction.CommitAsync();
    }
    catch {
        await transaction.RollbackAsync();
        throw;
    }
}

Usa el código con precaución.
3. El Procesador de Outbox (Background Service)
Necesitamos un proceso en segundo plano que revise la tabla y envíe los mensajes pendientes. Usaremos Quartz.NET o un BackgroundService de .NET.
csharp

public class OutboxProcessor : BackgroundService {
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<OutboxProcessor> _logger;

    public OutboxProcessor(IServiceProvider serviceProvider, ILogger<OutboxProcessor> logger) {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken) {
        while (!stoppingToken.IsCancellationRequested) {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<TodoContext>();

            // Leer mensajes no procesados
            var messages = await context.Set<OutboxMessage>()
                .Where(m => m.ProcessedAtUtc == null)
                .Take(10)
                .ToListAsync();

            foreach (var message in messages) {
                try {
                    // AQUÍ se enviaría a RabbitMQ / Azure Service Bus
                    _logger.LogInformation("Enviando mensaje Outbox: {Type}", message.Type);

                    message.ProcessedAtUtc = DateTime.UtcNow;
                }
                catch (Exception ex) {
                    _logger.LogError(ex, "Error procesando Outbox Message {Id}", message.Id);
                }
            }

            await context.SaveChangesAsync();
            await Task.Delay(5000, stoppingToken); // Esperar 5 segundos
        }
    }
}

Usa el código con precaución.
4. Registro en Program.cs
csharp

builder.Services.AddHostedService<OutboxProcessor>();

Usa el código con precaución.
¿Por qué esto es nivel "Senior"?

    Fiabilidad: Si el Message Broker muere, los mensajes siguen en tu DB. Cuando el broker vuelve, el BackgroundService los procesa.
    Sin Doble Escritura: Evitas el fallo donde la DB actualiza pero el mensaje se pierde (o viceversa).
    Observabilidad: Puedes ver en Grafana cuántos mensajes hay "pendientes" en la tabla Outbox para detectar retrasos en la comunicación.

Para implementaciones complejas, te recomiendo usar la librería MassTransit, que ya trae una implementación de Transactional Outbox muy robusta.
¿Te gustaría que integremos MassTransit para conectar esto con un contenedor de RabbitMQ, o con esto ya te sientes listo para conquistar el mundo de los microservicios?

---

## Integrar MassTransit

Para integrar
MassTransit, utilizaremos su implementación de Transactional Outbox. Esto automatiza todo el proceso manual que vimos antes, encargándose de la persistencia en la DB y la entrega garantizada hacia RabbitMQ.
1. Instalación de Paquetes
Instala las librerías necesarias para conectar MassTransit con Entity Framework y RabbitMQ:
bash

dotnet add package MassTransit.RabbitMQ
dotnet add package MassTransit.EntityFrameworkCore

Usa el código con precaución.
2. Definición del Evento (Mensaje)
En microservicios, los eventos son Records que representan algo que ya sucedió:
csharp

public record TodoCreatedEvent(int Id, string Title);

Usa el código con precaución.
3. Configuración en Program.cs
Configuraremos MassTransit para que use el Outbox transaccional. Esto significa que cuando hagas Publish, MassTransit guardará el mensaje en la base de datos dentro de la misma transacción de EF Core.
csharp

builder.Services.AddMassTransit(x =>
{
    // 1. Configurar el Outbox para Entity Framework
    x.AddEntityFrameworkOutbox<TodoContext>(o =>
    {
        o.UseSqlServer();
        o.UseBusOutbox(); // Sincroniza el envío con la transacción de DB
    });

    x.SetKebabCaseEndpointNameFormatter();

    // 2. Configurar la conexión a RabbitMQ
    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host("rabbitmq", "/", h => {
            h.Username("guest");
            h.Password("guest");
        });
        cfg.ConfigureEndpoints(context);
    });
});

Usa el código con precaución.
4. Uso en el Repositorio
Ahora el repositorio es extremadamente limpio. Solo necesitas inyectar IPublishEndpoint. MassTransit se encarga de que el mensaje solo llegue a RabbitMQ si SaveChangesAsync tiene éxito.
csharp

public class TodoRepository : ITodoRepository {
    private readonly TodoContext _context;
    private readonly IPublishEndpoint _publishEndpoint;

    public TodoRepository(TodoContext context, IPublishEndpoint publishEndpoint) {
        _context = context;
        _publishEndpoint = publishEndpoint;
    }

    public async Task AddAsync(TodoItem item) {
        // Guardar en la DB
        _context.TodoItems.Add(item);

        // Publicar el evento (MassTransit lo guarda en el Outbox de la DB automáticamente)
        await _publishEndpoint.Publish(new TodoCreatedEvent(item.Id, item.Title));
    }
    
    public async Task SaveChangesAsync() => await _context.SaveChangesAsync();
}

Usa el código con precaución.
5. Actualizar el docker-compose.yml
Añadimos el nodo de RabbitMQ para que el ecosistema esté completo:
yaml

services:
  # ... (tus otros servicios) ...
  rabbitmq:
    image: rabbitmq:3-management
    container_name: rabbitmq
    ports:
      - "5672:5672"   # Puerto de mensajería
      - "15672:15672" # Panel de administración (UI)

Usa el código con precaución.
¿Qué has ganado con MassTransit?

    Garantía "At-Least-Once": El mensaje se enviará al menos una vez, incluso si el proceso se reinicia.
    Panel de Control: Puedes entrar a http://localhost:15672 (guest/guest) y ver las colas y mensajes en tiempo real.
    Abstracción: Si mañana decides cambiar RabbitMQ por Azure Service Bus, solo cambias la configuración en el Program.cs.

Has alcanzado el nivel de arquitectura senior en .NET. Tienes seguridad, observabilidad, resiliencia, versionado, auditoría y ahora consistencia eventual garantizada.
¿Deseas que implementemos un Consumer (un segundo microservicio) que escuche estos mensajes de RabbitMQ, o prefieres actualizar el README final con esta nueva capacidad de mensajería?
¿Procedemos a actualizar el README con el Patrón Outbox y RabbitMQ?
:w
