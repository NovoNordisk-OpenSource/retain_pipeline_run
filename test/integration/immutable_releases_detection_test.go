package integration

import (
	"encoding/json"
	"testing"
)

func TestImmutableReleasesDetectionLogic(t *testing.T) {
	testCases := []struct {
		name           string
		repoInfo       string
		expectedResult string
	}{
		{
			name: "Organization repository with secret scanning",
			repoInfo: `{
				"owner": {"type": "Organization"},
				"security_and_analysis": {"secret_scanning": {"status": "enabled"}},
				"visibility": "private"
			}`,
			expectedResult: "likely",
		},
		{
			name: "Organization repository with push protection",
			repoInfo: `{
				"owner": {"type": "Organization"},
				"security_and_analysis": {"secret_scanning_push_protection": {"status": "enabled"}},
				"visibility": "public"
			}`,
			expectedResult: "likely",
		},
		{
			name: "Organization repository without advanced security",
			repoInfo: `{
				"owner": {"type": "Organization"},
				"security_and_analysis": null,
				"visibility": "private"
			}`,
			expectedResult: "supported",
		},
		{
			name: "User repository",
			repoInfo: `{
				"owner": {"type": "User"},
				"security_and_analysis": null,
				"visibility": "public"
			}`,
			expectedResult: "unsupported",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			var repoData map[string]interface{}
			if err := json.Unmarshal([]byte(tc.repoInfo), &repoData); err != nil {
				t.Fatalf("Failed to parse test repo info: %v", err)
			}

			result := detectImmutableReleases(repoData)
			if result != tc.expectedResult {
				t.Errorf("Expected %s, got %s for scenario: %s", tc.expectedResult, result, tc.name)
			}
		})
	}
}

// detectImmutableReleases simulates the logic from action.yml
func detectImmutableReleases(repoInfo map[string]interface{}) string {
	// Check owner type
	owner, ok := repoInfo["owner"].(map[string]interface{})
	if !ok {
		return "unknown"
	}

	ownerType, ok := owner["type"].(string)
	if !ok {
		return "unknown"
	}

	if ownerType != "Organization" {
		return "unsupported"
	}

	// Check security features
	securityAnalysis, ok := repoInfo["security_and_analysis"]
	if securityAnalysis == nil {
		return "supported"
	}

	securityMap, ok := securityAnalysis.(map[string]interface{})
	if !ok {
		return "supported"
	}

	// Check for secret scanning
	if secretScanning, exists := securityMap["secret_scanning"]; exists {
		if ssMap, ok := secretScanning.(map[string]interface{}); ok {
			if status, exists := ssMap["status"]; exists && status == "enabled" {
				return "likely"
			}
		}
	}

	// Check for push protection
	if pushProtection, exists := securityMap["secret_scanning_push_protection"]; exists {
		if ppMap, ok := pushProtection.(map[string]interface{}); ok {
			if status, exists := ppMap["status"]; exists && status == "enabled" {
				return "likely"
			}
		}
	}

	return "supported"
}