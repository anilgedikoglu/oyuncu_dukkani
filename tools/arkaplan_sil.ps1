# ASCII-only script. Turkish paths come from the filesystem, never hardcoded.
# Compiles a small C# helper: edge flood-fill white removal + framing normalize.
Add-Type -AssemblyName System.Drawing

$cs = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class BgKiller
{
    // Returns "OK w x h" or "EMPTY"
    public static string Process(string src, string dst, int outSize, int work,
                                 int thr, double fillRatio, int bottomPad)
    {
        Bitmap wb = new Bitmap(work, work, PixelFormat.Format32bppArgb);
        using (Image orig = Image.FromFile(src))
        using (Graphics g = Graphics.FromImage(wb))
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(orig, 0, 0, work, work);
        }

        Rectangle r = new Rectangle(0, 0, work, work);
        BitmapData bd = wb.LockBits(r, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int stride = bd.Stride;
        byte[] px = new byte[stride * work];
        Marshal.Copy(bd.Scan0, px, 0, px.Length);

        int n = work * work;
        bool[] bg = new bool[n];
        int[] stack = new int[n];
        int sp = 0;

        // seed from all four borders
        for (int i = 0; i < work; i++)
        {
            TrySeed(px, bg, stack, ref sp, stride, work, i, 0, thr);
            TrySeed(px, bg, stack, ref sp, stride, work, i, work - 1, thr);
            TrySeed(px, bg, stack, ref sp, stride, work, 0, i, thr);
            TrySeed(px, bg, stack, ref sp, stride, work, work - 1, i, thr);
        }

        // flood fill, 4-neighbour
        while (sp > 0)
        {
            int p = stack[--sp];
            int y = p / work, x = p - y * work;
            if (x > 0)        TrySeed(px, bg, stack, ref sp, stride, work, x - 1, y, thr);
            if (x < work - 1) TrySeed(px, bg, stack, ref sp, stride, work, x + 1, y, thr);
            if (y > 0)        TrySeed(px, bg, stack, ref sp, stride, work, x, y - 1, thr);
            if (y < work - 1) TrySeed(px, bg, stack, ref sp, stride, work, x, y + 1, thr);
        }

        // apply alpha + soften halo + measure content box
        int minX = work, minY = work, maxX = -1, maxY = -1;
        int soft = 205;
        for (int y = 0; y < work; y++)
        {
            int row = y * stride;
            for (int x = 0; x < work; x++)
            {
                int p = y * work + x;
                int o = row + x * 4;
                if (bg[p]) { px[o + 3] = 0; continue; }

                bool touch = (x > 0 && bg[p - 1]) || (x < work - 1 && bg[p + 1])
                          || (y > 0 && bg[p - work]) || (y < work - 1 && bg[p + work]);
                if (touch)
                {
                    int lo = Math.Min(px[o], Math.Min(px[o + 1], px[o + 2]));
                    if (lo > soft)
                    {
                        int a = (int)((double)(thr - lo) * 255.0 / (double)(thr - soft));
                        if (a < 0) a = 0; if (a > 255) a = 255;
                        px[o + 3] = (byte)a;
                    }
                }
                if (px[o + 3] > 25)
                {
                    if (x < minX) minX = x; if (x > maxX) maxX = x;
                    if (y < minY) minY = y; if (y > maxY) maxY = y;
                }
            }
        }
        // PASS 2: remove enclosed light blobs in the LOWER part of the figure
        // (leg-gap leaks and white ground shadows). Upper body is untouched so
        // white shirts and suits survive.
        if (maxY > minY)
        {
            int limitY = minY + (int)((maxY - minY) * 0.55);
            bool[] seen = new bool[n];
            int[] comp = new int[n];
            for (int y = limitY; y <= maxY; y++)
            {
                for (int x = minX; x <= maxX; x++)
                {
                    int p0 = y * work + x;
                    if (bg[p0] || seen[p0]) continue;
                    int o0 = y * stride + x * 4;
                    if (!IsLightNeutral(px, o0)) continue;

                    int cnt = 0; int qp = 0;
                    comp[qp++] = p0; seen[p0] = true;
                    int head = 0;
                    while (head < qp)
                    {
                        int p = comp[head++]; cnt++;
                        int py = p / work, pxx = p - py * work;
                        for (int d = 0; d < 4; d++)
                        {
                            int nx = pxx + (d == 0 ? -1 : d == 1 ? 1 : 0);
                            int ny = py + (d == 2 ? -1 : d == 3 ? 1 : 0);
                            if (nx < 0 || ny < 0 || nx >= work || ny >= work) continue;
                            int q = ny * work + nx;
                            if (bg[q] || seen[q]) continue;
                            if (!IsLightNeutral(px, ny * stride + nx * 4)) continue;
                            seen[q] = true; comp[qp++] = q;
                        }
                    }
                    if (cnt >= 150)
                        for (int k = 0; k < qp; k++)
                        {
                            int p = comp[k]; int py = p / work, pxx = p - py * work;
                            px[py * stride + pxx * 4 + 3] = 0; bg[p] = true;
                        }
                }
            }
            // recompute box
            minX = work; minY = work; maxX = -1; maxY = -1;
            for (int y = 0; y < work; y++)
                for (int x = 0; x < work; x++)
                    if (px[y * stride + x * 4 + 3] > 25)
                    {
                        if (x < minX) minX = x; if (x > maxX) maxX = x;
                        if (y < minY) minY = y; if (y > maxY) maxY = y;
                    }
        }

        Marshal.Copy(px, 0, bd.Scan0, px.Length);
        wb.UnlockBits(bd);

        if (maxX < minX || maxY < minY) { wb.Dispose(); return "EMPTY"; }

        int cw = maxX - minX + 1, ch = maxY - minY + 1;
        int th = (int)(outSize * fillRatio);
        double sc = (double)th / (double)ch;
        int nw = (int)(cw * sc), nh = th;
        if (nw > outSize) { nw = outSize; sc = (double)nw / (double)cw; nh = (int)(ch * sc); }

        Bitmap outBmp = new Bitmap(outSize, outSize, PixelFormat.Format32bppArgb);
        using (Graphics g2 = Graphics.FromImage(outBmp))
        {
            g2.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g2.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g2.CompositingQuality = CompositingQuality.HighQuality;
            g2.DrawImage(wb,
                new Rectangle((outSize - nw) / 2, outSize - bottomPad - nh, nw, nh),
                new Rectangle(minX, minY, cw, ch), GraphicsUnit.Pixel);
        }
        wb.Dispose();
        outBmp.Save(dst, ImageFormat.Png);
        outBmp.Dispose();
        return "OK " + nw + "x" + nh;
    }

    // Light AND neutral: background leak or grey shadow. Cream/tinted cloth fails this.
    static bool IsLightNeutral(byte[] px, int o)
    {
        int b = px[o], g = px[o + 1], r = px[o + 2];
        int lo = Math.Min(b, Math.Min(g, r));
        int hi = Math.Max(b, Math.Max(g, r));
        return lo >= 218 && (hi - lo) <= 22;
    }

    static void TrySeed(byte[] px, bool[] bg, int[] stack, ref int sp,
                        int stride, int work, int x, int y, int thr)
    {
        int p = y * work + x;
        if (bg[p]) return;
        int o = y * stride + x * 4;
        if (px[o] >= thr && px[o + 1] >= thr && px[o + 2] >= thr)
        {
            bg[p] = true;
            stack[sp++] = p;
        }
    }
}
"@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing
