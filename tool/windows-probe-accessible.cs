using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Accessibility;

public sealed class ProbeAccessible {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string className, string title);

    [DllImport("oleacc.dll")]
    private static extern int AccessibleObjectFromWindow(
        IntPtr window, uint objectId, ref Guid interfaceId,
        [MarshalAs(UnmanagedType.Interface)] out IAccessible accessible);

    [DllImport("oleacc.dll")]
    private static extern int AccessibleChildren(
        IAccessible parent, int start, int count,
        [Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)] object[] children, out int read);

    private readonly IAccessible accessible;
    private readonly int childId;

    private ProbeAccessible(IAccessible accessible, int childId) {
        this.accessible = accessible;
        this.childId = childId;
    }

    public string Name { get { return accessible.get_accName(childId); } }

    public void Invoke() {
        accessible.accDoDefaultAction(childId);
    }

    public static IEnumerable<ProbeAccessible> Read(IntPtr window) {
        var view = FindWindowEx(window, IntPtr.Zero, "FLUTTERVIEW", null);
        if (view == IntPtr.Zero) yield break;
        var interfaceId = typeof(IAccessible).GUID;
        IAccessible root;
        const uint clientObject = unchecked((uint)-4);
        if (AccessibleObjectFromWindow(view, clientObject, ref interfaceId, out root) != 0 || root == null)
            yield break;
        foreach (var item in Walk(root, 0)) yield return item;
    }

    private static IEnumerable<ProbeAccessible> Walk(IAccessible parent, int depth) {
        yield return new ProbeAccessible(parent, 0);
        int count = parent.accChildCount;
        if (count <= 0 || depth == 30) yield break;
        var children = new object[count];
        int read;
        if (AccessibleChildren(parent, 0, count, children, out read) < 0) yield break;
        for (int i = 0; i < read; i++) {
            var accessibleChild = children[i] as IAccessible;
            if (accessibleChild != null) {
                foreach (var item in Walk(accessibleChild, depth + 1)) yield return item;
            } else if (children[i] is int) {
                yield return new ProbeAccessible(parent, (int)children[i]);
            }
        }
    }
}
