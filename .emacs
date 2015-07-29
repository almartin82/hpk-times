(global-set-key "\017" 'goto-line)                     ;;; just easier
(global-set-key "\C-t" 'scroll-down)                   ;;; scroll back

(setq inhibit-splash-screen t)
(setq-default transient-mark-mode t)
(setq-default show-paren-mode t)

;; CPERL params
       (setq cperl-indent-level 4
          cperl-close-paren-offset -4
          cperl-continued-statement-offset 4
          cperl-indent-parens-as-block t
          cperl-tab-always-indent t)

(setq auto-mode-alist (mapcar 'purecopy
                              '(("\\.c$" . c-mode)
				("\\.f$" . fortran-mode)
				("\\.r$" . r-mode)
				("\\.R$" . r-mode)
				("\\.py$" . python-mode)
				("\\.i$" . c-mode)
				("\\.js$" . javascript-mode)
				("\\.php$" . php-mode)
				("Makefile" . makefile-mode)
				("Makefile.*" . makefile-mode)
				("\\.css$" . css-mode)
				("\\.ssi$" . html-mode)
				("\\.xhtml$" . html-mode)
				("\\.shtml$" . html-mode)
				("\\.htm$" . html-mode)
				("\\.java$" . java-mode)
                                ("\\.h$" . c-mode)
                                ("\\.a$" . c-mode)
				("\\.cpp$" . c-mode)
                                ("\\.hpp$" . c-mode)
                                ("\\.c++$" . c-mode)
                                ("\\.html$" . html-mode)
                                ("\\.pl$" . perl-mode)
                                ("\\.pm$" . perl-mode)
                                ("\\.cgi$" . perl-mode)
                                ("\\.tex$" . TeX-mode)
                                ("\\.txi$" . Texinfo-mode)
                                ("\\.el$" . emacs-lisp-mode)
				("\\.sql$" . sql-mode)
				("\\.bash*$" . sh-mode)
                        )))

(setq auto-save-interval 1000)   ;change to auto save after 1000 characters
(setq auto-save-timeout 300)   ;set to auto save after  min of idle

;; tabs and spaces
(setq-default indent-tabs-mode nil)     ; by default no tabs

;; Remove the stupid replacement of underscore with -> in statistics programs
(ess-toggle-underscore nil)

(custom-set-variables
  ;; custom-set-variables was added by Custom -- don't edit or cut/paste it!
  ;; Your init file should contain only one such instance.
 '(tool-bar-mode nil nil (tool-bar)))

