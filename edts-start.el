;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; EDTS Setup and configuration.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom edts-inhibit-package-check nil
  "If non-nil, don't check whether EDTS was installed as a package."
  :group 'edts)

(eval-after-load 'edts-start
  (unless (or edts-inhibit-package-check
              (and (fboundp 'package-installed-p)
                   (package-installed-p 'edts)))
    (error (concat
"EDTS was not installed as a package. Please see the README for more\n"
"information on how to install EDTS from MELPA.\n\n"
"If you know what you're doing and have all the necessary dependencies\n"
"installed (see edts-pkg.el) you can disable this check by setting\n"
"`edts-inhibit-package-check' to a non-nil value."))))

(eval-when-compile
  (compile "make libs"))

;; Prerequisites
(require 'erlang)
(require 'f)
(require 'woman)
(require 'ert nil 'noerror)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Paths

(eval-when-compile
  (defconst edts-root-directory
    (file-name-directory (or (locate-library "edts-start")
                             load-file-name
                             default-directory))
    "EDTS root directory.")

  (defconst edts-code-directory
    (f-join edts-root-directory "elisp" "edts")
    "Directory where edts code is located.")

  (defcustom edts-data-directory
    (if (boundp 'user-emacs-directory)
        (expand-file-name (concat user-emacs-directory "/edts"))
      (expand-file-name "~/.emacs.d"))
    "Where EDTS should save its data."
    :group 'edts)

  (defconst edts-lib-directory
    (f-join edts-root-directory "elisp")
    "Directory where edts libraries are located.")

  (defconst edts-plugin-directory
    (f-join edts-root-directory "plugins")
    "Directory where edts plugins are located.")

  (defconst edts-test-directory
    (f-join edts-root-directory "test")
    "Directory where edts test data are located.")

  (add-to-list 'load-path edts-code-directory)
  (require 'edts-plugin)
  (eval-when-compile
    (mapc #'(lambda (p) (add-to-list 'load-path
                                     (f-join edts-plugin-directory p)))
          (edts-plugin-names))))
(require 'edts)

(defcustom edts-erlang-mode-regexps
  '("^\\.erlang$"
    "\\.app$"
    "\\.app.src$"
    "\\.config$"
    "\\.erl$"
    "\\.es$"
    "\\.escript$"
    "\\.eterm$"
    "\\.script$"
    "\\.yaws$")
  "Additional extensions for which to auto-activate erlang-mode."
  :group 'edts)

;; workaround to get proper variable highlighting in the shell.
(defvar erlang-font-lock-keywords-vars
  (list
   (list
    #'(lambda (max)
        (block nil
          (while (re-search-forward erlang-variable-regexp max 'move-point)
            ;; no numerical constants
            (unless (eq ?# (char-before (match-beginning 0)))
              (return (match-string 0))))))
    1 'font-lock-variable-name-face nil))
  "Font lock keyword highlighting Erlang variables.
Must be preceded by `erlang-font-lock-keywords-macros' to work properly.")

;; HACKWARNING!! Avert your eyes lest you spend the rest ef your days in agony
;;
;; To avoid weird eproject types like generic-git interfering with us
;; make sure we only consider edts project types.
(defadvice eproject--all-types (around edts-eproject-types)
  "Ignore irrelevant eproject types for files where we should really only
consider EDTS."
  (let ((re (eproject--combine-regexps
             (cons "^\\.edts$" edts-erlang-mode-regexps)))
        (file-name (buffer-file-name)))
    ;; dired buffer has no file
    (if (and file-name
             (string-match re (f-filename file-name)))
        (setq ad-return-value '(edts-otp edts-temp edts generic))
      ad-do-it)))
(ad-activate-regexp "edts-eproject-types")

(defgroup edts nil
  "Erlang development tools"
  :group 'convenience
  :prefix "edts-")

(defvar edts-mode-hook nil
  "Hooks to run at the end of edts-mode initialization in a buffer.")

(defalias 'edts-inhibit-fringe-markers 'edts-face-inhibit-fringe-markers)
(defalias 'edts-marker-fringe 'edts-face-marker-fringe)

(defun edts-byte-compile ()
  "Byte-compile all elisp packages part of EDTS."
  (interactive)
  (let* ((dirs (directory-files edts-lib-directory t "^[^.]"))
         (files (apply #'append
                       (mapcar #'(lambda (dir)
                                   (directory-files dir t "\\.el$")) dirs))))
    (byte-compile-disable-warning 'cl-functions)
    (mapc #'byte-compile-file files)
    t))

;; Auto-activate erlang mode for some additional extensions.
(mapc #'(lambda(re) (add-to-list 'auto-mode-alist (cons re 'erlang-mode)))
      edts-erlang-mode-regexps)

;; Global setup
(edts-plugin-init-all)
(make-directory edts-data-directory 'parents)
(add-hook 'erlang-mode-hook 'edts-erlang-mode-hook)

(provide 'edts-start)
