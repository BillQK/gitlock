ExUnit.start()

ExUnit.after_suite(fn _ ->
  Briefly.cleanup()
end)
