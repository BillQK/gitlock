ExUnit.start()
# Ensure Briefly temp files are cleaned up after all tests
ExUnit.after_suite(fn _ ->
  Briefly.cleanup()
end)

Logger.configure(level: :none)
