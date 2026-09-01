#!/bin/bash

# Kasim Lecturer App Launcher  
# This script launches the Kasim lecturer application in a web browser

echo "========================================"
echo "  Kasim Lecturer App"
echo "  Access Control Engine"
echo "========================================"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter is not installed or not in PATH"
    echo "Please install Flutter from https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "🎓 Launching Kasim Lecturer App in browser..."
echo ""

# Navigate to the lecturer app directory
cd "$SCRIPT_DIR"

# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found"
    echo "Make sure you're running this script from the lecturer app directory"
    exit 1
fi

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Run the app in web browser
echo "🚀 Starting the application in your default browser..."
echo ""
echo "The app will be available at: http://localhost:7890"
echo ""
flutter run -d web --web-port=7890

