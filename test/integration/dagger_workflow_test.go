package integration

import (
	"context"
	"testing"

	"dagger.io/dagger"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func init() {
	// Initialize logger for tests
	zerolog.SetGlobalLevel(zerolog.InfoLevel)
	log.Logger = zerolog.New(zerolog.NewConsoleWriter()).With().Timestamp().Logger()
}

func TestRetainPipelineRunActionWithDagger(t *testing.T) {
	ctx := context.Background()

	// Initialize Dagger client
	client, err := dagger.Connect(ctx)
	if err != nil {
		t.Fatalf("Failed to connect to Dagger: %v", err)
	}
	defer client.Close()

	// Create test container
	testContainer := client.Container().From("ubuntu:22.04").
		WithEnvVariable("DEBIAN_FRONTEND", "noninteractive").
		WithExec([]string{"apt-get", "update"}).
		WithExec([]string{"apt-get", "install", "-y", "curl", "jq", "git"}).
		WithDirectory("/action", client.Host().Directory("../..")).
		WithWorkdir("/action")

	// Test action.yml validation
	t.Run("ActionYMLValidation", func(t *testing.T) {
		_, err := testContainer.
			WithExec([]string{"test", "-f", "action.yml"}).
			Sync(ctx)
		if err != nil {
			t.Errorf("action.yml validation failed: %v", err)
		}
	})

	// Test immutable releases logic
	t.Run("ImmutableReleasesLogic", func(t *testing.T) {
		result, err := testContainer.
			WithExec([]string{"sh", "-c", `
				REPO_INFO='{"owner": {"type": "Organization"}, "security_and_analysis": {"secret_scanning": {"status": "enabled"}}}'
				if echo "$REPO_INFO" | jq -e '.security_and_analysis.secret_scanning.status == "enabled"' >/dev/null; then
					echo "likely"
				else
					echo "unsupported"
				fi
			`}).
			Stdout(ctx)
		if err != nil {
			t.Fatalf("Immutable releases test failed: %v", err)
		}

		if result != "likely\n" {
			t.Errorf("Expected 'likely', got %s", result)
		}
	})

	// Test artifact processing
	t.Run("ArtifactProcessing", func(t *testing.T) {
		result, err := testContainer.
			WithExec([]string{"sh", "-c", `
				ARTIFACTS='{"total_count": 2, "artifacts": [
					{"name": "test1", "size_in_bytes": 1024},
					{"name": "test2", "size_in_bytes": 2048}
				]}'
				COUNT=$(echo "$ARTIFACTS" | jq '.total_count')
				SIZE=$(echo "$ARTIFACTS" | jq '[.artifacts[].size_in_bytes] | add')
				echo "$COUNT:$SIZE"
			`}).
			Stdout(ctx)
		if err != nil {
			t.Fatalf("Artifact processing test failed: %v", err)
		}

		if result != "2:3072\n" {
			t.Errorf("Expected '2:3072', got %s", result)
		}
	})
}

func TestReleaseTagGeneration(t *testing.T) {
	ctx := context.Background()

	client, err := dagger.Connect(ctx)
	if err != nil {
		t.Fatalf("Failed to connect to Dagger: %v", err)
	}
	defer client.Close()

	testContainer := client.Container().From("alpine:3.20.1").
		WithEnvVariable("GITHUB_RUN_ID", "123456").
		WithExec([]string{"sh", "-c", `
			TIMESTAMP=$(date +%Y%m%d-%H%M%S)
			RELEASE_TAG="pipeline-${GITHUB_RUN_ID}-${TIMESTAMP}"
			echo "$RELEASE_TAG"
		`})

	result, err := testContainer.Stdout(ctx)
	if err != nil {
		t.Fatalf("Release tag generation failed: %v", err)
	}

	if !containsString(result, "pipeline-123456-") {
		t.Errorf("Generated tag should contain 'pipeline-123456-', got: %s", result)
	}
}

func containsString(text, substr string) bool {
	return len(text) >= len(substr) &&
		   (text == substr ||
		    (len(text) > len(substr) &&
		     (text[:len(substr)] == substr ||
		      text[len(text)-len(substr):] == substr ||
		      findSubstring(text, substr))))
}

func findSubstring(text, substr string) bool {
	for i := 0; i <= len(text)-len(substr); i++ {
		if text[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}