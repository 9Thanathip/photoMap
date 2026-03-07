.PHONY: run-dev run-prod run-mock

run-dev:
	flutter run

run-prod:
	flutter run --release

run-mock:
	flutter run --dart-define=USE_MOCK=true
