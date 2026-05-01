#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_ROOT="$ROOT_DIR/test-results"

copy_junit_reports() {
	local source_dir="$1"
	local target_dir="$2"
	local prefix="$3"

	[[ -d "$source_dir" ]] || return 0

	while IFS= read -r -d '' file; do
		cp "$file" "$target_dir/${prefix}-$(basename "$file")"
	done < <(find "$source_dir" -type f -name "*.xml" -print0)
}

ensure_reports_exist() {
	local target_dir="$1"

	if ! find "$target_dir" -type f -name "*.xml" | grep -q .; then
		echo "Aucun rapport JUnit XML trouve dans $target_dir"
		return 1
	fi
}

run_node_tests() {
	local app_path="$1"
	local results_dir="$2"
	local code=0

	echo "Projet Node / Angular detecte"
	command -v npm >/dev/null || { echo "npm est introuvable"; return 1; }

	if [[ ! -d node_modules ]]; then
		if [[ -f package-lock.json ]]; then
			npm ci
		else
			npm install
		fi
	fi

	rm -rf reports test-results

	if npm run | grep -q "test:ci"; then
		npm run test:ci || code=$?
	else
		npm test -- --watch=false --browsers=ChromeHeadless --reporters=junit || code=$?
	fi

	copy_junit_reports "$app_path/reports" "$results_dir" "node"
	copy_junit_reports "$app_path/test-results" "$results_dir" "node"
	rm -rf reports test-results

	ensure_reports_exist "$results_dir" || return 1
	return "$code"
}

run_gradle_tests() {
	local app_path="$1"
	local results_dir="$2"
	local code=0

	echo "Projet Java / Gradle detecte"
	if [[ -n "${JAVA_HOME:-}" ]]; then
		export PATH="$JAVA_HOME/bin:$PATH"
	fi
	command -v java >/dev/null || { echo "java est introuvable"; return 1; }
	java -version

	rm -rf build/test-results build/reports/tests

	if [[ -f gradlew ]]; then
		chmod +x ./gradlew
		./gradlew clean test --no-daemon || code=$?
	else
		command -v gradle >/dev/null || { echo "gradle est introuvable"; return 1; }
		gradle clean test --no-daemon || code=$?
	fi

	copy_junit_reports "$app_path/build/test-results/test" "$results_dir" "gradle"
	ensure_reports_exist "$results_dir" || return 1
	return "$code"
}

run_maven_tests() {
	local app_path="$1"
	local results_dir="$2"
	local code=0

	echo "Projet Java / Maven detecte"

	rm -rf target/surefire-reports

	if [[ -f mvnw ]]; then
		chmod +x ./mvnw
		./mvnw test || code=$?
	else
		command -v mvn >/dev/null || { echo "mvn est introuvable"; return 1; }
		mvn test || code=$?
	fi

	copy_junit_reports "$app_path/target/surefire-reports" "$results_dir" "maven"
	ensure_reports_exist "$results_dir" || return 1
	return "$code"
}

run_app() {
	local app_path="$1"
	local app_name="${2:-$(basename "$app_path")}"
	local results_dir="$RESULTS_ROOT/$app_name"

	app_path="$(cd "$app_path" && pwd)"

	echo
	echo "Application: $app_name"
	echo "Chemin: $app_path"
	echo "Rapports: $results_dir"

	rm -rf "$results_dir"
	mkdir -p "$results_dir"

	cd "$app_path"

	if [[ -f package.json ]]; then
		run_node_tests "$app_path" "$results_dir"
	elif [[ -f build.gradle || -f build.gradle.kts || -f gradlew ]]; then
		run_gradle_tests "$app_path" "$results_dir"
	elif [[ -f pom.xml || -f mvnw ]]; then
		run_maven_tests "$app_path" "$results_dir"
	else
		echo "Type de projet non reconnu dans $app_path"
		return 1
	fi
}

find_apps() {
	find "$ROOT_DIR" -mindepth 1 -maxdepth 1 -type d \
		! -name ".git" \
		! -name ".github" \
		! -name ".vscode" \
		! -name "scripts" \
		! -name "test-results" \
		-print0
}

main() {
	local failed=0

	if [[ $# -gt 0 ]]; then
		run_app "$1" "${2:-$(basename "$1")}"
		return
	fi

	rm -rf "$RESULTS_ROOT"
	mkdir -p "$RESULTS_ROOT"

	while IFS= read -r -d '' app_path; do
		if [[ -f "$app_path/package.json" || -f "$app_path/build.gradle" || -f "$app_path/build.gradle.kts" || -f "$app_path/pom.xml" ]]; then
			run_app "$app_path" || failed=1
			cd "$ROOT_DIR"
		fi
	done < <(find_apps)

	if [[ "$failed" -ne 0 ]]; then
		echo
		echo "Au moins une application a echoue."
		return 1
	fi

	echo
	echo "Tests termines. Rapports JUnit XML dans $RESULTS_ROOT"
}

main "$@"
