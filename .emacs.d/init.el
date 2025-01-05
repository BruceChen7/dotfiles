(setq custom-file "~/.emacs.d/.emacs.custom.el")
(package-initialize)

(tool-bar-mode 0)  ; Disable the tool bar (icons at the top)
(menu-bar-mode 0)  ; Disable the menu bar (File, Edit, etc.)
(scroll-bar-mode 0)  ; Disable the scroll bar on the right
(column-number-mode 1)  ; Show column number in the mode line
(show-paren-mode 1)  ; Highlight matching parentheses



(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

(add-to-list 'default-frame-alist '(font . "Iosevka-14"))
