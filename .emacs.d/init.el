;;(setq inhibit-startup-message t)             ; 关闭启动 Emacs 时的欢迎界面
(setq visible-bell nil)
(setq gc-cons-threshold (* 100 1024 1024))
(electric-pair-mode t)                       ; 自动补全括号
(add-hook 'prog-mode-hook #'show-paren-mode) ; 编程模式下，光标在括号上时高亮另一个括号
(column-number-mode t)                       ; 在 Mode line 上显示列号
(global-auto-revert-mode t)                  ; 当另一程序修改了文件时，让 Emacs 及时刷新 Buffer
(delete-selection-mode t)                    ; 选中文本后输入文本会替换文本（更符合我们习惯了的其它编辑器的逻辑）
(setq make-backup-files nil)                 ; 关闭文件自动备份
(setq auto-save-default nil)                 ; 关闭文件自动备份
(add-hook 'prog-mode-hook #'hs-minor-mode)   ; 编程模式下，可以折叠代码块
(global-display-line-numbers-mode 1)         ; 在 Window 显示行号
(tool-bar-mode -1)                           ; 关闭 Tool bar
(menu-bar-mode -1)                           ; 关闭 Tool bar
(when (display-graphic-p) (toggle-scroll-bar -1)) ; 图形界面时关闭滚动条

(savehist-mode 0)                            ; （可选）打开 Buffer 历史记录保存
(setq display-line-numbers-type 'relative)   ; （可选）显示相对行号

;; make :q just kill the buffer
(global-set-key [remap evil-quit] 'kill-buffer-and-window)
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)
(fset 'yes-or-no-p 'y-or-n-p)

(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

(recentf-mode 1)
(setq recentf-max-menu-items 25)
(setq recentf-max-saved-items 25)

(setq inhibit-splash-screen t)
(setq inhibit-startup-message t)
(setq initial-scratch-message "")
(setq initial-major-mode (quote fundamental-mode))

(require 'package)
(setq package-archives '(("gnu"   . "http://mirrors.cloud.tencent.com/elpa/gnu/")
                         ("melpa" . "http://mirrors.cloud.tencent.com/elpa/melpa/")))
(package-initialize)



(eval-when-compile
  (require 'use-package))


;;(use-package dashboard
;;  :ensure t
;;  :config
;;  (dashboard-setup-startup-hook))

(use-package counsel
  :ensure t)


(use-package highlight-indent-guides
  :ensure t
  :config
    (add-hook 'prog-mode-hook 'highlight-indent-guides-mode))


(use-package all-the-icons
  :ensure t)


(use-package doom-modeline
  :ensure t
  :config
  (setq doom-modeline-support-imenu t) 
  (setq doom-modeline-project-detection 'auto)
  :init (doom-modeline-mode 1))

(use-package ivy
  :diminish
  :ensure t            
  :bind(("C-s" . swiper)
	("C-c r" . counsel-recentf)
	:map ivy-minibuffer-map
	("TAB" . ivy-alt-done)
	("C-l" . ivy-alt-done)
	("C-j" . ivy-next-line)
	("C-k" . ivy-previous-line)
	:map ivy-switch-buffer-map
	("C-k" . ivy-previous-line)
	("C-l" . ivy-done)
	("C-d" . ivy-switch-buffer-kill))
  :config    
  (ivy-mode 1))                     


(load-theme 'atom-one-dark t)


(use-package projectile
  :ensure t
  :config
  (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)
  (projectile-mode +1))

(use-package company
  :hook ((prog-mode . company-mode)
         (inferior-emacs-lisp-mode . company-mode))
  :config (setq company-minimum-prefix-length 1
                company-show-quick-access nil))
	  (define-key company-active-map (kbd "C-j") 'company-select-next)
          (define-key company-active-map (kbd "C-k") 'company-select-previous))


(use-package ivy-posframe
 :ensure t
 :config
 (setq ivy-posframe-display-functions-alist '((t . ivy-posframe-display-at-window-center)))
 (ivy-posframe-mode 1))

(use-package projectile
  :ensure t
  :config
  (setq projectile-sort-order 'recently-active)
  (setq projectile-enable-caching t)
  (setq projectile-completion-system 'ivy)
  (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)
  (projectile-mode +1))

;; used to move cursor fastly
(use-package avy
 :ensure t)

;;(global-set-key (kbd "C-'") 'avy-goto-char-2)

;;(use-package good-scroll
;;  :ensure t
;;  :init (good-scroll-mode 1))

;; (setq evil-want-integration t) ;; This is optional since it's already set to t by default.
;; (setq evil-wan
(use-package evil
  :ensure t
  :init
  (setq evil-want-integration t)
  (setq evil-want-C-u-scroll t)
  ;;(setq evil-want-keybinding nil)
  :config
  (evil-mode 1))

(use-package evil-leader
  :ensure t
  :init
  (global-evil-leader-mode)
  (evil-leader/set-leader "<SPC>")
 )

(evil-leader/set-key
  "f" 'find-file
  "b" 'switch-to-buffer
  "k" 'kill-buffer
  "s" 'avy-goto-char-2)


;; Company mode
(setq company-idle-delay 0)
(setq company-minimum-prefix-length 3)


(setq lsp-ui-doc-enable t
    lsp-ui-peek-enable t
    lsp-ui-sideline-enable t
    lsp-ui-imenu-enable t
    lsp-ui-sideline-show-hover nil
    lsp-ui-doc-position 'at-point
    lsp-ui-flycheck-enable t)

;; LSP
(use-package lsp-mode
  :init
  (setq lsp-keymap-prefix "C-c l")
  :hook ((python-mode . lsp-deferred)
         (go-mode . lsp-deferred)
         (rust-mode . lsp-deferred))
  :commands (lsp lsp-deferred))

;; Set up before-save hooks to format buffer and add/delete imports.
;; Make sure you don't have other gofmt/goimports hooks enabled.
;; (defun lsp-go-install-save-hooks ()
;;   (add-hook 'before-save-hook #'lsp-format-buffer t t)
;;   (add-hook 'before-save-hook #'lsp-organize-imports t t))
;; (add-hook 'go-mode-hook #'lsp-go-install-save-hooks)

(use-package go-mode
  :hook ((go-mode . lsp-deferred)
         (before-save . lsp-format-buffer)
         (before-save . lsp-organize-imports)))

(provide 'lang-go)


(provide 'init)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(highlight-indent-guides-method 'bitmap)
 '(package-selected-packages
   '(company zzz-to-char lsp-ui go-mode use-package lsp-mode counsel)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
