using System;
using System.IO;
using System.Reflection;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.ApplicationServices;

namespace DiagProbe
{
    public class P
    {
        const string PdfOut = @"D:/Claude/batchplot-plugin/research/runtime-test/_probe.pdf";
        const string Log = @"D:/Claude/batchplot-plugin/research/runtime-test/diag_result.txt";
        static void W(string s) { try { File.AppendAllText(Log, s + "\r\n"); } catch { } }

        [CommandMethod("DIAGNET8")]
        public void Run()
        {
            try { File.Delete(Log); } catch { }
            // 修复尝试：注册 CodePages provider（.NET Core 默认不含 1252/936 等编码）
            System.Type cpType = System.Type.GetType(
                "System.Text.CodePagesEncodingProvider, System.Text.Encoding.CodePages", false);
            W("CodePagesEncodingProvider type: " + (cpType == null ? "NULL (assembly not loaded)" : cpType.FullName));
            if (cpType != null)
            {
                try
                {
                    object inst = cpType.GetProperty("Instance").GetValue(null, null);
                    System.Text.Encoding.RegisterProvider((System.Text.EncodingProvider)inst);
                    W("RegisterProvider OK");
                    System.Text.Encoding e1252 = System.Text.Encoding.GetEncoding(1252);
                    W("encoding 1252 => " + e1252.WebName);
                }
                catch (System.Exception ex)
                {
                    W("RegisterProvider FAIL: " + ex.GetType().FullName + " :: " + ex.Message);
                }
            }
            else
            {
                W("=> 需要引用 System.Text.Encoding.CodePages 包/程序集才能修真");
            }
            W("=== net8 environment diag ===");
            W("Runtime: " + System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription);
            W("CLR: " + Environment.Version);
            W("Process: " + System.Diagnostics.Process.GetCurrentProcess().ProcessName);

            // 1) 尝试加载 PdfSharp 1.5
            try
            {
                Assembly a = Assembly.LoadFrom(@"D:\Claude\batchplot-plugin\research\runtime-test\PdfSharp.dll");
                W("PdfSharp loaded: " + a.FullName);
                Type t = a.GetType("PdfSharp.Pdf.PdfDocument");
                W("PdfDocument type: " + (t == null ? "NULL" : t.FullName));
                if (t != null)
                {
                    object doc = Activator.CreateInstance(t);
                    W("PdfDocument instance created OK");
                    object pg = t.GetMethod("AddPage", Type.EmptyTypes).Invoke(doc, null);
                    W("AddPage OK: " + (pg == null ? "null" : pg.GetType().Name));
                    t.GetMethod("Save", new Type[] { typeof(string) }).Invoke(doc, new object[] { @"D:\Claude\batchplot-plugin\research\runtime-test\_probe.pdf" });
                    W("Save OK");
                    t.GetMethod("Close").Invoke(doc, null);
                    W("Close OK");
                    long sz = new FileInfo(PdfOut).Length;
                    W("PROBE PDF SIZE = " + sz);
                }
            }
            catch (System.Exception ex)
            {
                W("PdfSharp FAIL: " + ex.GetType().FullName + " :: " + ex.Message);
                if (ex.InnerException != null) W("  inner: " + ex.InnerException.GetType().FullName + " :: " + ex.InnerException.Message);
            }
            W("=== end ===");
        }
    }
}
