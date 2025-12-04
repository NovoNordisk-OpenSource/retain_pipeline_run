package unit

import (
	"os"
	"path/filepath"
	"testing"
	"gopkg.in/yaml.v3"
)

func TestActionYmlExists(t *testing.T) {
	actionPath := filepath.Join("..", "..", "action.yml")
	if _, err := os.Stat(actionPath); os.IsNotExist(err) {
		t.Errorf("action.yml file does not exist at %s", actionPath)
	}
}

func TestActionYmlIsValidYAML(t *testing.T) {
	actionPath := filepath.Join("..", "..", "action.yml")

	data, err := os.ReadFile(actionPath)
	if err != nil {
		t.Fatalf("Failed to read action.yml: %v", err)
	}

	var actionConfig map[string]interface{}
	err = yaml.Unmarshal(data, &actionConfig)
	if err != nil {
		t.Errorf("action.yml is not valid YAML: %v", err)
	}
}

func TestActionYmlHasRequiredFields(t *testing.T) {
	actionPath := filepath.Join("..", "..", "action.yml")

	data, err := os.ReadFile(actionPath)
	if err != nil {
		t.Fatalf("Failed to read action.yml: %v", err)
	}

	var actionConfig map[string]interface{}
	err = yaml.Unmarshal(data, &actionConfig)
	if err != nil {
		t.Fatalf("action.yml is not valid YAML: %v", err)
	}

	// Test required fields
	requiredFields := []string{"name", "description", "inputs", "outputs", "runs"}
	for _, field := range requiredFields {
		if _, exists := actionConfig[field]; !exists {
			t.Errorf("action.yml missing required field: %s", field)
		}
	}

	// Test that it's a composite action
	runs, ok := actionConfig["runs"].(map[string]interface{})
	if !ok {
		t.Errorf("action.yml 'runs' field is not a map")
		return
	}

	using, ok := runs["using"].(string)
	if !ok || using != "composite" {
		t.Errorf("action.yml should use 'composite' type, got: %v", using)
	}
}

func TestActionYmlHasGithubTokenInput(t *testing.T) {
	actionPath := filepath.Join("..", "..", "action.yml")

	data, err := os.ReadFile(actionPath)
	if err != nil {
		t.Fatalf("Failed to read action.yml: %v", err)
	}

	var actionConfig map[string]interface{}
	err = yaml.Unmarshal(data, &actionConfig)
	if err != nil {
		t.Fatalf("action.yml is not valid YAML: %v", err)
	}

	inputs, ok := actionConfig["inputs"].(map[string]interface{})
	if !ok {
		t.Errorf("action.yml 'inputs' field is not a map")
		return
	}

	githubToken, exists := inputs["github_token"]
	if !exists {
		t.Errorf("action.yml missing required input: github_token")
		return
	}

	tokenConfig, ok := githubToken.(map[string]interface{})
	if !ok {
		t.Errorf("github_token input is not properly configured")
		return
	}

	required, exists := tokenConfig["required"]
	if !exists || required != true {
		t.Errorf("github_token input should be required")
	}
}