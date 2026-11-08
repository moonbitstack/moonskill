# The typeface

`harmonyos-sans-sc-regular.woff` and `harmonyos-sans-sc-bold.woff` are Latin
subsets of **HarmonyOS Sans SC**, the face this site sets its body and titles
in. The full family, which also covers Chinese, is published by Huawei Device
Co., Ltd. and is free to use; see the official download page for the licence
text that governs it:

<https://developer.huawei.com/consumer/cn/design/resource>

The subsets are produced with `pyftsubset` from the official TTFs, keeping the
Latin script, the punctuation the pages use and the typographic features that
matter here (kerning, standard and discretionary ligatures, tabular figures).
They are 16 KB each rather than several megabytes, which is the only reason a
subset is shipped at all.

Regenerate with:

```sh
pyftsubset HarmonyOS_Sans_SC_Regular.ttf \
  --output-file=harmonyos-sans-sc-regular.woff \
  --flavor=woff \
  --layout-features='kern,liga,clig,calt,tnum,lnum' \
  --unicodes="U+0020-007E,U+00A0-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+2000-206F,U+20AC,U+2122,U+2190-2193,U+2212,U+2215,U+FEFF,U+FFFD" \
  --no-hinting --desubroutinize
```

The same options produce the bold file from `HarmonyOS_Sans_SC_Bold.ttf`.
