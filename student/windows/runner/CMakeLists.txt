cmake_minimum_required(VERSION 3.14)
project(kasim_student LANGUAGES CXX)

set(BINARY_NAME "kasim_student")

# Target Windows desktop runner build rules
add_executable(${BINARY_NAME} WIN32
  "main.cpp"
)
