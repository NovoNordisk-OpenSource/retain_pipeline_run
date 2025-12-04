module github.com/NovoNordisk-OpenSource/retain_pipeline_run/test/unit

go 1.23

require (
	dagger.io/dagger v0.15.3
	github.com/rs/zerolog v1.31.0
	gopkg.in/yaml.v3 v3.0.1
	github.com/NovoNordisk-OpenSource/retain_pipeline_run v0.0.0-00010101000000-000000000000
)

replace github.com/NovoNordisk-OpenSource/retain_pipeline_run => ../..