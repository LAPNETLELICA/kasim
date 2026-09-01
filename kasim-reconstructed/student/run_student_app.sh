#!/bin/bash

# Kasim Student App Launcher
# This script launches the Kasim student exam application on Linux desktop

echo "========================================"
echo "  Kasim Student Secure Exam Client"
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

echo "📱 Launching Kasim Student App..."
echo ""

# Navigate to the student app directory
cd "$SCRIPT_DIR"

# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found"
    echo "Make sure you're running this script from the student app directory"
    exit 1
fi

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Generate Linux platform files if not present
if [ ! -d "linux" ]; then
    echo "🔧 Setting up Linux platform support..."
    flutter create . --platforms=linux
fi

# Run the app
echo "🚀 Starting the application..."
flutter run -d linux

