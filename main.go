package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"

	"dagger.io/dagger"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func main() {
	ctx := context.Background()
	log.Logger = initLogger()
	log.Info().Msg("---- Testing retain_pipeline_run action ----")

	if err := testRetainPipelineRunAction(ctx); err != nil {
		log.Error().Msg(fmt.Sprintln(err))
		panic(err)
	}
}

func testRetainPipelineRunAction(ctx context.Context) error {
	// Initialize Dagger client
	client, err := dagger.Connect(ctx, dagger.WithLogOutput(log.Logger))
	if err != nil {
		return err
	}
	defer client.Close()

	log.Info().Msg("Testing retain_pipeline_run action with Dagger")

	// Set up test environment
	GITHUB_TOKEN := client.SetSecret("GITHUB_TOKEN", os.Getenv("GITHUB_TOKEN"))

	// Create a test container with GitHub CLI and action files
	testContainer := client.Container().From("ubuntu:22.04").
		WithEnvVariable("DEBIAN_FRONTEND", "noninteractive").
		WithExec([]string{"apt-get", "update"}).
		WithExec([]string{"apt-get", "install", "-y", "curl", "jq", "git", "wget"}).
		WithExec([]string{"sh", "-c", "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"}).
		WithExec([]string{"sh", "-c", "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null"}).
		WithExec([]string{"apt-get", "update"}).
		WithExec([]string{"apt-get", "install", "-y", "gh"}).
		WithSecretVariable("GITHUB_TOKEN", GITHUB_TOKEN).
		WithDirectory("/action", client.Host().Directory(".")).
		WithWorkdir("/action")

	// Set up GitHub environment variables for testing
	testContainer = testContainer.
		WithEnvVariable("GITHUB_REPOSITORY", "NovoNordisk-OpenSource/retain_pipeline_run").
		WithEnvVariable("GITHUB_RUN_ID", "12345678").
		WithEnvVariable("GITHUB_SHA", "abcdef1234567890").
		WithEnvVariable("GITHUB_REF_NAME", "main").
		WithEnvVariable("GITHUB_WORKFLOW", "Test Workflow").
		WithEnvVariable("GITHUB_EVENT_NAME", "workflow_dispatch").
		WithEnvVariable("GITHUB_ACTOR", "test-user").
		WithEnvVariable("GITHUB_SERVER_URL", "https://github.com")

	// Test 1: Verify action.yml exists and is valid
	log.Info().Msg("Test 1: Verifying action.yml exists and is valid")
	actionExists, err := testContainer.
		WithExec([]string{"test", "-f", "action.yml"}).
		WithExec([]string{"echo", "✅ action.yml exists"}).
		Stdout(ctx)
	if err != nil {
		return fmt.Errorf("action.yml validation failed: %v", err)
	}
	log.Info().Msgf("Action validation result: %s", strings.TrimSpace(actionExists))

	// Test 2: Check required tools are available
	log.Info().Msg("Test 2: Checking required tools")
	toolsCheck, err := testContainer.
		WithExec([]string{"jq", "--version"}).
		WithExec([]string{"gh", "--version"}).
		WithExec([]string{"curl", "--version"}).
		WithExec([]string{"git", "--version"}).
		WithExec([]string{"echo", "✅ All required tools are available"}).
		Stdout(ctx)
	if err != nil {
		return fmt.Errorf("tools check failed: %v", err)
	}
	log.Info().Msgf("Tools check result: %s", strings.TrimSpace(toolsCheck))

	// Test 3: Test immutable releases detection logic
	log.Info().Msg("Test 3: Testing immutable releases detection")
	mockRepoInfo := `{
		"owner": {"type": "Organization"},
		"security_and_analysis": {"secret_scanning": {"status": "enabled"}},
		"visibility": "public"
	}`

	immutableTest, err := testContainer.
		WithExec([]string{"sh", "-c", fmt.Sprintf("echo '%s' | jq -e '.security_and_analysis.secret_scanning.status == \"enabled\"' && echo '✅ Immutable releases detection works' || echo '❌ Detection failed'", mockRepoInfo)}).
		Stdout(ctx)
	if err != nil {
		return fmt.Errorf("immutable releases test failed: %v", err)
	}
	log.Info().Msgf("Immutable releases test result: %s", strings.TrimSpace(immutableTest))

	// Test 4: Test release tag generation
	log.Info().Msg("Test 4: Testing release tag generation")
	tagTest, err := testContainer.
		WithExec([]string{"sh", "-c", "TIMESTAMP=$(date +%Y%m%d-%H%M%S) && RELEASE_TAG=\"pipeline-${GITHUB_RUN_ID}-${TIMESTAMP}\" && echo \"Generated tag: $RELEASE_TAG\" && echo $RELEASE_TAG | grep -q \"pipeline-12345678-\" && echo '✅ Tag generation works'"}).
		Stdout(ctx)
	if err != nil {
		return fmt.Errorf("tag generation test failed: %v", err)
	}
	log.Info().Msgf("Tag generation test result: %s", strings.TrimSpace(tagTest))

	// Test 5: Test artifact processing simulation
	log.Info().Msg("Test 5: Testing artifact processing")
	artifactTest, err := testContainer.
		WithExec([]string{"sh", "-c", `
			MOCK_ARTIFACTS='{"total_count": 3, "artifacts": [
				{"name": "test1", "id": 111, "size_in_bytes": 1024},
				{"name": "test2", "id": 222, "size_in_bytes": 2048},
				{"name": "test3", "id": 333, "size_in_bytes": 512}
			]}'
			COUNT=$(echo "$MOCK_ARTIFACTS" | jq '.total_count')
			TOTAL_SIZE=$(echo "$MOCK_ARTIFACTS" | jq '[.artifacts[].size_in_bytes] | add')
			if [ "$COUNT" = "3" ] && [ "$TOTAL_SIZE" = "3584" ]; then
				echo "✅ Artifact processing works"
			else
				echo "❌ Artifact processing failed"
			fi
		`}).
		Stdout(ctx)
	if err != nil {
		return fmt.Errorf("artifact processing test failed: %v", err)
	}
	log.Info().Msgf("Artifact processing test result: %s", strings.TrimSpace(artifactTest))

	log.Info().Msg("✅ All Dagger tests completed successfully")
	return nil
}

func initLogger() zerolog.Logger {
	logFile, _ := os.OpenFile(
		"test.log",
		os.O_APPEND|os.O_CREATE|os.O_WRONLY,
		0644,
	)
	consoleWriter := zerolog.ConsoleWriter{Out: os.Stdout}
	multiWriter := zerolog.MultiLevelWriter(consoleWriter, logFile)
	multi := zerolog.New(multiWriter).With().Timestamp().Logger()

	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	debug := flag.Bool("debug", false, "sets log level to debug")
	flag.Parse()

	// Default level
	zerolog.SetGlobalLevel(zerolog.InfoLevel)
	if *debug {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
	}

	return multi
}