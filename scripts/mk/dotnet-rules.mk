

.PHONY: build
build:  ## Build the application
	dotnet build

.PHONY: test
test:  ## Run the tests
	dotnet test
	reportgenerator -reports:"**/TestResults/**/coverage.cobertura.xml" -targetdir:"coveragereport" -reporttypes:Markdown

# .PHONY: deps
# deps:
	# dotnet add package Microsoft.


