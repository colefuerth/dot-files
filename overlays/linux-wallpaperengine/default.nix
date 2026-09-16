# Web-type Wallpaper Engine wallpapers render pure black upstream. CEF is set up
# for offscreen rendering, so every painted frame arrives in
# RenderHandler::OnPaint, which uploads it with glBindTexture + glTexImage2D --
# but the id it binds comes from texture(), and that returned
# getWallpaperFramebuffer() (the FBO's name) instead of getWallpaperTexture()
# (the FBO's colour attachment). Framebuffers and textures are separate GL name
# spaces, so the upload lands on whatever texture happens to share the
# framebuffer's number and the wallpaper's own texture is never written --
# leaving it black. CWeb::setSize, a few lines away, binds the texture
# correctly, which is what makes the mismatch obvious.
#
# Both name spaces start numbering at 1, so in a simple enough setup the two ids
# can coincide and the bug hides itself -- presumably why this isn't broken for
# everyone. Video and scene wallpapers never touch this path and always worked.
#
# Reported upstream as Almamu/linux-wallpaperengine; drop this overlay once a
# release carries the fix (packaged version is 0.0.1-unstable-2026-06-09, which
# was upstream HEAD as of 2026-09-15).
final: prev: {
  linux-wallpaperengine = prev.linux-wallpaperengine.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./web-render-to-texture.patch
    ];
  });
}
