using System;
using System.IO;
using System.Text;
using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.Geometry;

namespace MkBlk
{
    public class M
    {
        static readonly string OutDir = Environment.GetEnvironmentVariable("BPBLK_OUT") ?? Path.GetTempPath();
        static readonly string Log = Path.Combine(OutDir, "mkblk.log");
        static void W(string s) { try { File.AppendAllText(Log, s + Environment.NewLine, Encoding.UTF8); } catch { } }

        [CommandMethod("MKBLK")]
        public void Run()
        {
            try { File.Delete(Log); } catch { }
            Document doc = Application.DocumentManager.MdiActiveDocument;
            if (doc == null) { W("no doc"); return; }
            // 全新库：避免继承 empty.dwg 里残留的多段线干扰统计
            Database db = new Database(true, true);
            {
                using (Transaction tr = db.TransactionManager.StartTransaction())
                {
                    BlockTable bt = (BlockTable)tr.GetObject(db.BlockTableId, OpenMode.ForRead);
                    BlockTableRecord ms = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);

                    // 图框块定义：矩形 42000x29700 (A3@1:100) + 5 个属性
            // 块名刻意不含 图框/TK/FRAME，属性标签刻意用拼音：验证 BPTEACH 学习前后行为差异
                    string bname = "TITLEBLOCK_A3";
                    ObjectId btrId;
                    if (!bt.Has(bname))
                    {
                        bt.UpgradeOpen();
                        BlockTableRecord btr = new BlockTableRecord();
                        btr.Name = bname;
                        btrId = bt.Add(btr);
                        tr.AddNewlyCreatedDBObject(btr, true);
                        AddRect(btr, tr, 0, 0, 42000, 29700);
                        AddAttr(btr, tr, "TUHAO", "图号", 2000, 26000);
                        AddAttr(btr, tr, "TUMING", "图名", 2000, 23000);
                        AddAttr(btr, tr, "BILI", "比例", 2000, 20000);
                        AddAttr(btr, tr, "BANCI", "版次", 2000, 17000);
                        AddAttr(btr, tr, "RIQI", "日期", 2000, 14000);
                    }
                    else btrId = bt[bname];

                    // 插入 2 个图框 + 框内内容（内容必须是模型空间独立实体，
                    // 否则 CountVisibleInWindow 只看到图框自身 → 判为空窗 SKIP）
                    InsertFrame(tr, ms, btrId, 0, 0, "建-101", "建筑设计说明", "1:100", "A", "2024.01.01");
                    AddContent(tr, ms, 10000, 10000, "说明文字 A");
                    AddContent(tr, ms, 30000, 20000, "说明文字 B");
                    InsertFrame(tr, ms, btrId, 60000, 0, "建-102", "首层平面图", "1:100", "A", "2024.01.01");
                    AddContent(tr, ms, 70000, 10000, "平面内容 1");
                    AddContent(tr, ms, 90000, 20000, "平面内容 2");
                    tr.Commit();
                }
                db.SaveAs(Path.Combine(OutDir, "blk.dwg"), DwgVersion.Current);
                W("SAVED " + Path.Combine(OutDir, "blk.dwg"));
            }
        }

        static void AddContent(Transaction tr, BlockTableRecord ms, double cx, double cy, string label)
        {
            Circle c = new Circle(new Point3d(cx, cy, 0), Vector3d.ZAxis, 3000);
            ms.AppendEntity(c);
            tr.AddNewlyCreatedDBObject(c, true);
            Line ln = new Line(new Point3d(cx - 6000, cy - 6000, 0), new Point3d(cx + 6000, cy + 6000, 0));
            ms.AppendEntity(ln);
            tr.AddNewlyCreatedDBObject(ln, true);
            DBText tx = new DBText();
            tx.Position = new Point3d(cx - 4000, cy + 7000, 0);
            tx.Height = 1500;
            tx.TextString = label;
            ms.AppendEntity(tx);
            tr.AddNewlyCreatedDBObject(tx, true);
        }

        static void AddRect(BlockTableRecord btr, Transaction tr, double x, double y, double w, double h)
        {
            Polyline pl = new Polyline(4);
            pl.AddVertexAt(0, new Point2d(x, y), 0, 0, 0);
            pl.AddVertexAt(1, new Point2d(x + w, y), 0, 0, 0);
            pl.AddVertexAt(2, new Point2d(x + w, y + h), 0, 0, 0);
            pl.AddVertexAt(3, new Point2d(x, y + h), 0, 0, 0);
            pl.Closed = true;
            btr.AppendEntity(pl);
            tr.AddNewlyCreatedDBObject(pl, true);
        }

        static void AddAttr(BlockTableRecord btr, Transaction tr, string tag, string prompt, double x, double y)
        {
            AttributeDefinition ad = new AttributeDefinition();
            ad.Tag = tag;
            ad.Prompt = prompt;
            ad.TextString = "";
            ad.Position = new Point3d(x, y, 0);
            ad.Height = 300;
            ad.Verifiable = false;
            ad.Invisible = false;
            ad.Constant = false;
            ad.Preset = false;
            btr.AppendEntity(ad);
            tr.AddNewlyCreatedDBObject(ad, true);
        }

        static void InsertFrame(Transaction tr, BlockTableRecord ms, ObjectId btrId, double x, double y,
            string num, string title, string scale, string rev, string date)
        {
            BlockReference br = new BlockReference(new Point3d(x, y, 0), btrId);
            ms.AppendEntity(br);
            tr.AddNewlyCreatedDBObject(br, true);
            BlockTableRecord btr = (BlockTableRecord)tr.GetObject(btrId, OpenMode.ForRead);
            foreach (ObjectId id in btr)
            {
                AttributeDefinition ad = tr.GetObject(id, OpenMode.ForRead) as AttributeDefinition;
                if (ad == null) continue;
                AttributeReference ar = new AttributeReference();
                ar.SetAttributeFromBlock(ad, br.BlockTransform);
                string v = "";
                if (ad.Tag == "TUHAO") v = num;
                else if (ad.Tag == "TUMING") v = title;
                else if (ad.Tag == "BILI") v = scale;
                else if (ad.Tag == "BANCI") v = rev;
                else if (ad.Tag == "RIQI") v = date;
                ar.TextString = v;
                br.AttributeCollection.AppendAttribute(ar);
                tr.AddNewlyCreatedDBObject(ar, true);
            }
        }
    }
}
