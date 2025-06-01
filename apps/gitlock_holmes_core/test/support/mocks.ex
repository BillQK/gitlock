defmodule GitlockHolmesCore.TestSupport.Mocks do
  Mox.defmock(GitlockHolmesCore.Mocks.VersionControlMock,
    for: GitlockHolmesCore.Ports.VersionControlPort
  )

  Mox.defmock(GitlockHolmesCore.Mocks.ReporterMock,
    for: GitlockHolmesCore.Ports.ReportPort
  )

  Mox.defmock(GitlockHolmesCore.Mocks.ComplexityAnalyzerMock,
    for: GitlockHolmesCore.Ports.ComplexityAnalyzerPort
  )

  Mox.defmock(GitlockHolmesCore.Mocks.FileSystemMock,
    for: GitlockHolmesCore.Ports.FileSystemPort
  )
end
