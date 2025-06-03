Mox.defmock(GitlockCore.Mocks.VersionControlMock,
  for: GitlockCore.Ports.VersionControlPort
)

Mox.defmock(GitlockCore.Mocks.ReporterMock,
  for: GitlockCore.Ports.ReportPort
)

Mox.defmock(GitlockCore.Mocks.FileSystemMock,
  for: GitlockCore.Ports.FileSystemPort
)

Mox.defmock(GitlockCore.Mocks.ComplexityAnalyzerMock,
  for: GitlockCore.Ports.ComplexityAnalyzerPort
)
