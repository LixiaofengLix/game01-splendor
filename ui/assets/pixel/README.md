# ui/assets/pixel/

生成的像素贴图：9 宫格边框（`frame_*`）、金币（`coin_*`）、宝石形状（`gem_*`）、吉祥物（`mascot_*`）、
平铺底纹（`tile_*`）。重新生成：

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . ui/tools/build_pixel_assets.tscn
```

不要直接改这里的 PNG；改点阵定义请改 `ui/tools/build_pixel_assets.gd` 并同步样张。
