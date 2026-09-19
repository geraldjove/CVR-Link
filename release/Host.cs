using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

[assembly: AssemblyTitle("CVR Link")]
[assembly: AssemblyDescription("Mouse, key and HUD settings for CVRFlatscreen")]
[assembly: AssemblyVersion("0.2.69.0")]
[assembly: AssemblyFileVersion("0.2.69.0")]
static class Program {
    [STAThread] static int Main(string[] args) {
        Application.EnableVisualStyles();
        try {
            string mode = args.Length == 0 ? "open" : args[0];
            if (mode != "open" && mode != "--uninstall" && mode != "--check" && mode != "--install-elevated")
                throw new InvalidOperationException("Open CVR Link without extra command options.");
            if (mode == "open" || mode == "--uninstall") {
                using (var existing = new Mutex(false, @"Local\ContractorsFlatscreenControl")) {
                    if (!existing.WaitOne(0)) {
                        MessageBox.Show("CVR Link is already open. Close its other window first.", "CVR Link");
                        return 0;
                    }
                    existing.ReleaseMutex();
                }
            }
            string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (mode == "--check") {
                local = Path.Combine(Path.GetTempPath(), "CVRLink-check-" + Guid.NewGuid().ToString("N"));
                Environment.SetEnvironmentVariable("LOCALAPPDATA", local);
            }
            string folder = Path.Combine(local, "CVRLink", "app", "0.2.69");
            for (string path = folder; path != null && path.Length >= local.Length; path = Path.GetDirectoryName(path)) {
                if (Directory.Exists(path) && (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
                    throw new IOException("CVR Link cannot install through a folder link or junction.");
            }
            Directory.CreateDirectory(folder);
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
            using (var archive = new ZipArchive(stream, ZipArchiveMode.Read)) {
                foreach (var entry in archive.Entries) {
                    string target = Path.GetFullPath(Path.Combine(folder, entry.FullName));
                    if (!target.StartsWith(folder + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("The app package contains an invalid file path.");
                    if (entry.Name.Length == 0) continue;
                    if (File.Exists(target) && (File.GetAttributes(target) & FileAttributes.ReparsePoint) != 0)
                        throw new IOException("CVR Link cannot replace a linked app file.");
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    using (var input = entry.Open()) using (var output = File.Create(target)) input.CopyTo(output);
                }
            }
            string installed = Path.Combine(folder, "CVRLink.exe");
            string current = Assembly.GetExecutingAssembly().Location;
            if (mode != "--check" && !string.Equals(current, installed, StringComparison.OrdinalIgnoreCase))
                File.Copy(current, installed, true);
            using (var runspace = RunspaceFactory.CreateRunspace()) {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using (var ps = PowerShell.Create()) {
                    ps.Runspace = runspace;
                    // Run the packaged script as a file so its own paths stay relative.
                    ps.AddCommand("Set-ExecutionPolicy").AddParameter("Scope", "Process").AddParameter("ExecutionPolicy", "Bypass").AddParameter("Force");
                    ps.Invoke();
                    if (ps.HadErrors) throw new InvalidOperationException("Windows policy blocked CVR Link. Ask your PC administrator for help.");
                    ps.Commands.Clear();
                    ps.AddCommand(Path.Combine(folder, "Launcher.ps1")).AddParameter("Executable", installed).AddParameter("Mode", mode);
                    if (mode == "--install-elevated") {
                        if (args.Length != 3) throw new InvalidOperationException("Missing setup folder.");
                        ps.AddParameter("GameBin", args[1]).AddParameter("StateRoot", args[2]);
                    }
                    ps.Invoke();
                    if (ps.HadErrors) throw new InvalidOperationException(ps.Streams.Error[0].ToString());
                }
            }
            return 0;
        } catch (Exception error) {
            if (args.Length > 0 && args[0] == "--check") {
                File.WriteAllText(Path.Combine(Path.GetTempPath(), "CVRLink-check-error.txt"), error.ToString());
            } else MessageBox.Show(error.Message, "CVR Link", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
