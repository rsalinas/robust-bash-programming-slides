#FORMAT:=revealjs
FORMAT:=slidy

view: robustsh.html
	google-chrome $<

robustsh.html: robustsh.md Makefile
	pandoc -t $(FORMAT) -s $< -o $@ -s

.phony: xdg-open
xdg-open: robustsh.html
	xdg-open "$<"