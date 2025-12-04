module github.com/NovoNordisk-OpenSource/retain_pipeline_run/test/integration

go 1.23

require (
	dagger.io/dagger v0.15.3
	github.com/rs/zerolog v1.31.0
	github.com/NovoNordisk-OpenSource/retain_pipeline_run v0.0.0-00010101000000-000000000000
)

replace github.com/NovoNordisk-OpenSource/retain_pipeline_run => ../..