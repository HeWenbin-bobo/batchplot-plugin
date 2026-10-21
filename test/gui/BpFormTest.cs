using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

namespace FormTest
{
    static class Prog
    {
        static readonly string Log = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "bpform_test.log");
        static StringBuilder SB = new StringBuilder();
        static void W(string s) { SB.AppendLine(DateTime.Now.ToString("HH:mm:ss.fff ") + s); }
        static int fails = 0;
        static void Chk(string name, bool ok, string detail)
        {
            if (!ok) fails++;
            W((ok ? "  OK   " : "  FAIL ") + name + (detail == null ? "" : "  <" + detail + ">"));
        }

        [STAThread]
        static void Main()
        {
            AppDomain.CurrentDomain.AssemblyResolve += delegate(object s, ResolveEventArgs e)
            {
                string cad = Environment.GetEnvironmentVariable("ACAD_DIR");
                if (string.IsNullOrEmpty(cad)) cad = @"D:\Program Files\Autodesk\AutoCAD 2025";
                string p = Path.Combine(cad, new AssemblyName(e.Name).Name + ".dll");
                if (File.Exists(p)) return Assembly.LoadFrom(p);
                return null;
            };
            try { Run(); }
            catch (Exception ex) { W("FATAL " + ex); fails++; }
            W("RESULT fails=" + fails);
            File.WriteAllText(Log, SB.ToString(), new UTF8Encoding(false));
            Environment.Exit(fails == 0 ? 0 : 1);
        }

        static void Run()
        {
            var frames = new List<BpPlot.FrameInfo>
            {
                new BpPlot.FrameInfo { MinX=0, MinY=0, MaxX=118900, MaxY=84100, Number="A-101", Title="总平面图", Scale=100 },
                new BpPlot.FrameInfo { MinX=200000, MinY=0, MaxX=259410, MaxY=84100, Number="A-102", Title="首层平面", Scale=100 },
                new BpPlot.FrameInfo { MinX=400000, MinY=0, MaxX=429700, MaxY=21000, Number=null, Title=null, Scale=0 },
            };
            var medias = new List<BpPlot.Media>
            {
                new BpPlot.Media { CanonicalName="ISO_A0_(841.00_x_1189.00_MM)", W=841,  H=1189 },
                new BpPlot.Media { CanonicalName="ISO_A1_(594.00_x_841.00_MM)",  W=594,  H=841  },
                new BpPlot.Media { CanonicalName="ISO_A4_(210.00_x_297.00_MM)",  W=210,  H=297  },
            };

            var form = new BpPlot.BpForm(frames, medias, 100, System.IO.Path.Combine(System.IO.Path.GetTempPath(), "bpform_out"), "合成.dwg");
            form.Show();                 // PerformClick 要求控件可见才生效
            Application.DoEvents();
            W("ctor OK, Text=" + form.Text + " Visible=" + form.Visible);
            Chk("标题含版本号", form.Text.Contains("v0.7"), form.Text);

            var grid = Find<DataGridView>(form);
            var txtDir = Find<TextBox>(form);
            var chkMono = FindCheck(form, "黑白");
            var chkMerge = FindCheck(form, "合成");
            var numMargin = Find<NumericUpDown>(form);
            Chk("DataGridView 存在", grid != null, null);
            Chk("输出目录 TextBox 存在", txtDir != null, txtDir == null ? null : txtDir.Text);
            Chk("黑白 CheckBox 存在且默认勾选", chkMono != null && chkMono.Checked, null);
            Chk("合成 CheckBox 存在且默认不勾", chkMerge != null && !chkMerge.Checked, null);
            Chk("留白 NumericUpDown 存在且范围 -50..50",
                numMargin != null && numMargin.Minimum == -50 && numMargin.Maximum == 50,
                numMargin == null ? null : numMargin.Minimum + ".." + numMargin.Maximum);

            Chk("行数=3", grid.Rows.Count == 3, "" + grid.Rows.Count);
            string[] cols = new string[grid.Columns.Count];
            for (int i = 0; i < grid.Columns.Count; i++) cols[i] = grid.Columns[i].HeaderText;
            W("  列: " + string.Join(" | ", cols));
            Chk("列数=6", grid.Columns.Count == 6, "" + grid.Columns.Count);

            bool allSel = true;
            for (int i = 0; i < grid.Rows.Count; i++) if (!(bool)grid.Rows[i].Cells["sel"].Value) allSel = false;
            Chk("默认全选", allSel, null);

            for (int i = 0; i < grid.Rows.Count; i++)
                W("  row" + i + " num=[" + grid.Rows[i].Cells["num"].Value + "] title=[" + grid.Rows[i].Cells["title"].Value
                  + "] scale=[" + grid.Rows[i].Cells["scale"].Value + "] fname=[" + grid.Rows[i].Cells["fname"].Value
                  + "] paper=[" + grid.Rows[i].Cells["paper"].Value + "]");

            var btnNone = FindButton(form, "全不选");
            var btnAll = FindButton(form, "全选");
            Chk("全不选/全选按钮存在", btnNone != null && btnAll != null, null);
            if (btnNone != null) { btnNone.PerformClick(); }
            bool noneSel = true;
            for (int i = 0; i < grid.Rows.Count; i++) if ((bool)grid.Rows[i].Cells["sel"].Value) noneSel = false;
            Chk("点全不选后全部未勾选", noneSel, null);
            if (btnAll != null) { btnAll.PerformClick(); }
            allSel = true;
            for (int i = 0; i < grid.Rows.Count; i++) if (!(bool)grid.Rows[i].Cells["sel"].Value) allSel = false;
            Chk("点全选后全部勾选", allSel, null);

            grid.Rows[0].Cells["scale"].Value = "200";
            Application.DoEvents();
            W("  after scale=200 row0 paper=[" + grid.Rows[0].Cells["paper"].Value + "]");
            Chk("改比例后纸张预览非空", ("" + grid.Rows[0].Cells["paper"].Value).Length > 0, "" + grid.Rows[0].Cells["paper"].Value);

            if (numMargin != null) { numMargin.Value = 10; Application.DoEvents(); }
            W("  after margin=10 row1 paper=[" + grid.Rows[1].Cells["paper"].Value + "]");

            grid.Rows[1].Cells["fname"].Value = "自定义名";
            grid.Rows[2].Cells["sel"].Value = false;

            if (chkMerge != null) chkMerge.Checked = true;
            if (numMargin != null) numMargin.Value = 5;
            var btnOk = FindButton(form, "出 图");
            Chk("出图按钮存在", btnOk != null, null);
            if (btnOk != null) btnOk.PerformClick();
            Application.DoEvents();

            W("  DialogResult=" + form.DialogResult + " Selected=" + (form.Selected == null ? -1 : form.Selected.Count));
            Chk("点出图后 DialogResult=OK", form.DialogResult == DialogResult.OK, "" + form.DialogResult);
            Chk("Selected 数量=2（第3行未勾）", form.Selected != null && form.Selected.Count == 2,
                form.Selected == null ? "null" : "" + form.Selected.Count);
            if (form.Selected != null && form.Selected.Count == 2)
            {
                Chk("Selected[0].Scale=200（行内改比例写回）", form.Selected[0].Scale == 200, "" + form.Selected[0].Scale);
                Chk("Selected[1].NameOverride=自定义名", form.Selected[1].NameOverride == "自定义名", form.Selected[1].NameOverride);
            }
            Chk("Merge=true", form.Merge, "" + form.Merge);
            Chk("Margin=5", Math.Abs(form.Margin - 5) < 0.001, "" + form.Margin);
            Chk("Mono=true", form.Mono, "" + form.Mono);
            Chk("OutDir 保留", form.OutDir == System.IO.Path.Combine(System.IO.Path.GetTempPath(), "bpform_out"), form.OutDir);

            var form2 = new BpPlot.BpForm(frames, medias, 100, @"C:\tmp", "x.dwg");
            form2.Show();
            Application.DoEvents();
            var c2 = FindButton(form2, "取消");
            Chk("取消按钮存在", c2 != null, null);
            if (c2 != null) c2.PerformClick();
            Application.DoEvents();
            Chk("取消后 DialogResult=Cancel", form2.DialogResult == DialogResult.Cancel, "" + form2.DialogResult);
            Chk("取消后 Selected 为空", form2.Selected == null || form2.Selected.Count == 0,
                form2.Selected == null ? "null" : "" + form2.Selected.Count);

            // ---- 排序风险：行号→_frames 索引是位置绑定，列一旦可排序就会错位 ----
            var form3 = new BpPlot.BpForm(frames, medias, 100, @"C:\tmp", "s.dwg");
            form3.Show();
            Application.DoEvents();
            var g3 = Find<DataGridView>(form3);
            int sortable = 0;
            for (int i = 0; i < g3.Columns.Count; i++)
                if (g3.Columns[i].SortMode != DataGridViewColumnSortMode.NotSortable) sortable++;
            W("  可排序列数=" + sortable);
            Chk("全部列不可排序（行号绑定 _frames 索引）", sortable == 0, "" + sortable);
            try
            {
                g3.Sort(g3.Columns["num"], System.ComponentModel.ListSortDirection.Descending);
                bool sorted = ("" + g3.Rows[0].Cells["num"].Value) == "A-102";
                W("  Sort 调用后首行 num=[" + g3.Rows[0].Cells["num"].Value + "] sorted=" + sorted);
                Chk("排序不会真正打乱行序", sorted, "" + g3.Rows[0].Cells["num"].Value);
            }
            catch (InvalidOperationException ex)
            {
                W("  Sort 抛 InvalidOperationException（不可排序 = 符合预期）: " + ex.Message);
                Chk("排序被拒绝", true, null);
            }
            form3.Dispose();

            // ---- 排序错位实证：排序后改文件名，看写回的是哪一框 ----
            // 若列可排序，r.Index 与 _frames 索引脱钩 => 比例/文件名落到错误的图框上（静默错图）
            var form4 = new BpPlot.BpForm(frames, medias, 100, @"C:\tmp", "w.dwg");
            form4.Show();
            Application.DoEvents();
            var g4 = Find<DataGridView>(form4);
            bool canSort = g4.Columns["num"].SortMode != DataGridViewColumnSortMode.NotSortable;
            if (canSort)
            {
                g4.Sort(g4.Columns["num"], System.ComponentModel.ListSortDirection.Descending);
                Application.DoEvents();
            }
            string shown0 = "" + g4.Rows[0].Cells["num"].Value;   // 排序后首行显示 A-102
            g4.Rows[0].Cells["fname"].Value = "FIRST_ROW_NAME";
            var ok4 = FindButton(form4, "出 图");
            if (ok4 != null) ok4.PerformClick();
            Application.DoEvents();
            string landedOn = "(none)";
            if (form4.Selected != null && form4.Selected.Count > 0)
                landedOn = form4.Selected[0].Number + "/" + form4.Selected[0].NameOverride;
            W("  排序后首行显示=" + shown0 + "  写回落到=" + landedOn);
            Chk("首行显示与写回目标一致（无错位）", landedOn == shown0 + "/FIRST_ROW_NAME", landedOn);
            form4.Dispose();
        }

        static T Find<T>(Control root) where T : Control
        {
            foreach (Control c in root.Controls)
            {
                T t = c as T;
                if (t != null) return t;
                T r = Find<T>(c);
                if (r != null) return r;
            }
            return null;
        }
        static CheckBox FindCheck(Control root, string frag)
        {
            foreach (Control c in root.Controls)
            {
                CheckBox cb = c as CheckBox;
                if (cb != null && cb.Text.Contains(frag)) return cb;
                CheckBox r = FindCheck(c, frag);
                if (r != null) return r;
            }
            return null;
        }
        static Button FindButton(Control root, string text)
        {
            foreach (Control c in root.Controls)
            {
                Button b = c as Button;
                if (b != null && b.Text == text) return b;
                Button r = FindButton(c, text);
                if (r != null) return r;
            }
            return null;
        }
    }
}
