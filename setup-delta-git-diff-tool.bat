git config --global delta.true-color always
REM fills the whole row using the BG color
git config --global delta.line-fill-method ansi
REM helpful env hint for some shells
setx COLORTERM truecolor

git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global pager.diff "delta --side-by-side --line-numbers"
git config --global pager.show "delta --side-by-side --line-numbers"
git config --global pager.log  "delta --side-by-side --line-numbers"
git config --global delta.features "side-by-side line-numbers decorations navigate"
git config --global delta.syntax-theme "DarkNeon"
git config --global delta.side-by-side true
git config --global delta.navigate true

git config --global delta.file-style "#00a6fb"
git config --global delta.grep-file-style "bold #ff6b35"
git config --global delta.line-numbers-zero-style "#eeeeee"
git config --global delta.line-numbers-left-style  "bold #ffd400"
git config --global delta.line-numbers-right-style  "bold #1aae5c"
git config --global delta.line-numbers-minus-style  "bold red"
git config --global delta.line-numbers-plus-style  "bold #1DD45F"

git config --global delta.plus-style                    "bold #eeeeee #1DD45F"
git config --global delta.plus-non-emph-style           "#eeeeee #1DD45F"
git config --global delta.plus-emph-style               "bold #eeeeee #1DD45F"
git config --global delta.plus-empty-line-marker-style  "#eeeeee #1DD45F"
git config --global delta.minus-style                   "bold #eeeeee #ff002b"
git config --global delta.minus-non-emph-style          "#eeeeee #ff002b"
git config --global delta.minus-emph-style              "bold #eeeeee #ff002b"
git config --global delta.minus-empty-line-marker-style "#eeeeee #ff002b"
