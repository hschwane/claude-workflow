# CONFIGURE_DEPENDS so a newly added test file is picked up when ci.sh's prepare stage
# reconfigures. Without it a brand-new test is silently not built, and the gate is green
# having never compiled the test just written.
file(GLOB UNIT_SRCS CONFIGURE_DEPENDS unit/*.cpp)
foreach(src ${UNIT_SRCS})
  get_filename_component(name ${src} NAME_WE)
  add_executable(${name} ${src})
  target_link_libraries(${name} PRIVATE fixture_core)
  add_test(NAME ${name} COMMAND ${name})
  set_tests_properties(${name} PROPERTIES LABELS unit)
endforeach()

file(GLOB INT_SRCS CONFIGURE_DEPENDS integration/*.cpp)
foreach(src ${INT_SRCS})
  get_filename_component(name ${src} NAME_WE)
  add_executable(${name} ${src})
  target_link_libraries(${name} PRIVATE fixture_core)
  add_test(NAME ${name} COMMAND ${name})
  set_tests_properties(${name} PROPERTIES LABELS integration)
endforeach()
