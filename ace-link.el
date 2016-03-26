;;; ace-link.el --- Quickly follow links

;; Copyright (C) 2014-2015 Oleh Krehel

;; Author: Oleh Krehel <ohwoeowho@gmail.com>
;; URL: https://github.com/abo-abo/ace-link
;; Version: 0.3.0
;; Package-Requires: ((avy "0.2.0"))
;; Keywords: convenience, links

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This package offers an alternative to tabbing through links in
;; buffers, for instance, in an Info buffer.  `avy' is used to turn
;; opening a link from an O(N) operation into an O(1).
;;
;; Use `ace-link-setup-default' to set up the default bindings, which currently
;; bind e.g. `ace-link-info' to "o", which was previously unbound and is
;; close to "l" (which by default goes back).
;;
;; Supported modes: `Info-mode', `help-mode', `org-mode', `eww-mode',
;; `gnus-article-mode', `Custom-mode', `woman-mode', `goto-address-mode'.

;;; Code:
(require 'avy)

;;* Commands
;;** Info
;;;###autoload
(defun ace-link-info ()
  "Open a visible link in an `Info-mode' buffer."
  (interactive)
  (let ((pt (avy-with ace-link-info
               (avy--process
                (mapcar #'cdr
                        (ace-link--info-collect))
                #'avy--overlay-post))))
    (ace-link--info-action pt)))

(defun ace-link--info-action (pt)
  (when (numberp pt)
    (push-mark)
    (goto-char pt)
    (let ((we (window-end)))
      (while (not (ignore-errors
                    (Info-follow-nearest-node)))
        (forward-char 1)
        (when (> (point) we)
          (error "Could not follow link"))))))

(declare-function Info-follow-nearest-node "info")
(declare-function Info-next-reference "info")
(declare-function Info-try-follow-nearest-node "info")
(declare-function Info-goto-node "info")

(defun ace-link--info-current ()
  "Return the node at point."
  (cons (cl-letf (((symbol-function #'Info-goto-node)
                   (lambda (node _) node)))
          (Info-try-follow-nearest-node))
        (point)))

(defun ace-link--info-collect ()
  "Collect the positions of visible links in the current `Info-mode' buffer."
  (let ((end (window-end))
        points)
    (save-excursion
      (goto-char (window-start))
      (when (ignore-errors (Info-next-reference) t)
        (push (ace-link--info-current) points)
        (Info-next-reference)
        (while (and (< (point) end)
                    (> (point) (cdar points)))
          (push (ace-link--info-current) points)
          (Info-next-reference))
        (nreverse points)))))

;;** Help
;;;###autoload
(defun ace-link-help ()
  "Open a visible link in a `help-mode' buffer."
  (interactive)
  (let ((pt (avy-with ace-link-help
              (avy--process
               (mapcar #'cdr (ace-link--help-collect))
               #'avy--overlay-post))))
    (ace-link--help-action pt)))

(defun ace-link--help-action (pt)
  (when (numberp pt)
    (goto-char (1+ pt))
    (push-button)))

(defun ace-link--help-collect ()
  "Collect the positions of visible links in the current `help-mode' buffer."
  (let ((skip (text-property-any
               (point-min) (point-max) 'button nil))
        candidates)
    (save-excursion
      (while (setq skip (text-property-not-all
                         skip (point-max) 'button nil))
        (goto-char skip)
        (push (cons (button-label (button-at skip)) skip) candidates)
        (setq skip (text-property-any (point) (point-max)
                                      'button nil))))
    (nreverse candidates)))

;;** WoMan
;;;###autoload
(defun ace-link-woman ()
  "Open a visible link in a `woman-mode' buffer."
  (interactive)
  (let ((pt (avy-with ace-link-woman
              (avy--process
               (mapcar #'cdr (ace-link--woman-collect))
               #'avy--overlay-post))))
    (ace-link--woman-action pt)))

(defun ace-link--woman-action (pt)
  (when (number-or-marker-p pt)
    (goto-char (1+ pt))
    (push-button)))

(defun ace-link--woman-collect ()
  "Collect all links visible in the current `woman-mode' buffer."
  (let ((end (window-end))
        candidates)
    (save-excursion
      (goto-char (window-start))
      (while (and (condition-case nil (forward-button 1)
                    (error nil))
                  (< (point) end))
        (push (cons (button-label (button-at (point))) (point))
              candidates))
      (nreverse candidates))))

;;** EWW
;;;###autoload
(defun ace-link-eww ()
  "Open a visible link in an `eww-mode' buffer."
  (interactive)
  (let ((pt (avy-with ace-link-eww
              (avy--process
               (mapcar #'cdr (ace-link--eww-collect))
               #'avy--overlay-post))))
    (ace-link--eww-action pt)))

(declare-function eww-follow-link "eww")

(defun ace-link--eww-action (pt)
  (when (number-or-marker-p pt)
    (goto-char (1+ pt))
    (eww-follow-link)))

(defun ace-link--eww-collect ()
  "Collect the positions of visible links in the current `eww' buffer."
  (save-excursion
    (save-restriction
      (narrow-to-region
       (window-start)
       (window-end))
      (goto-char (point-min))
      (let (beg end candidates)
        (setq end (text-property-any
                   (point) (point-max) 'help-echo nil))
        (while (setq beg (text-property-not-all
                          end (point-max) 'help-echo nil))
          (goto-char beg)
          (setq end (text-property-any
                     (point) (point-max) 'help-echo nil))
          (push (cons (buffer-substring-no-properties beg end) beg)
                candidates))
        (nreverse candidates)))))

;;** Compilation
;;;###autoload
(defun ace-link-compilation ()
  "Open a visible link in a `compilation-mode' buffer."
  (interactive)
  (let ((res (avy-with ace-link-compilation
               (avy--process
                (mapcar #'cdr (ace-link--eww-collect))
                #'avy--overlay-post))))
    (when res
      (goto-char (1+ res))
      (compile-goto-error))))

(declare-function compile-goto-error "compile")

;;** GNUS
(declare-function gnus-summary-widget-forward "gnus-sum")
(declare-function widget-button-press "wid-edit")

;;;###autoload
(defun ace-link-gnus ()
  "Open a visible link in a `gnus-article-mode' buffer."
  (interactive)
  (when (eq major-mode 'gnus-summary-mode)
    (gnus-summary-widget-forward 1))
  (let ((res (avy-with ace-link-gnus
               (avy--process
                (ali--gnus-collect-references)
                #'avy--overlay-post))))
    (when res
      (goto-char (1+ res))
      (widget-button-press (point)))))

;;** Org
(declare-function org-open-at-point "org")

;;;###autoload
(defun ace-link-org ()
  "Open a visible link in an `org-mode' buffer."
  (interactive)
  (require 'org)
  (let ((res (avy-with ace-link-org
               (avy--process
                (ali--org-collect-references)
                #'avy--overlay-pre))))
    (when (numberp res)
      (goto-char res)
      (org-open-at-point))))

(declare-function Custom-newline "cus-edit")

;;;###autoload
(defun ace-link-custom ()
  "Open a visible link in an `Custom-mode' buffer."
  (interactive)
  (let ((res (avy-with ace-link-custom
               (avy--process
                (ali--custom-collect-references)
                #'avy--overlay-pre))))
    (when res
      (goto-char res)
      (Custom-newline (point)))))

;;;###autoload
(defun ace-link-addr ()
  "Open a visible link in a goto-address buffer."
  (interactive)
  (let ((res (avy-with ace-link-addr
               (avy--process
                (ali--addr-collect-references)
                #'avy--overlay-pre))))
    (when (number-or-marker-p res)
      (goto-char (1+ res))
      (goto-address-at-point))))

;;* Internals
(declare-function widget-forward "wid-edit")
(defun ali--gnus-collect-references ()
  "Collect the positions of visible links in the current gnus buffer."
  (require 'wid-edit)
  (let (candidates pt)
    (save-excursion
      (save-restriction
        (narrow-to-region
         (window-start)
         (window-end))
        (goto-char (point-min))
        (setq pt (point))
        (while (progn (widget-forward 1)
                      (> (point) pt))
          (setq pt (point))
          (when (or (plist-get (text-properties-at (point)) 'gnus-string)
                    (plist-get (text-properties-at (point)) 'shr-url))
            (push (point) candidates)))
        (nreverse candidates)))))

(defun ali--custom-collect-references ()
  "Collect the positions of visible links in the current `Custom-mode' buffer."
  (let (candidates pt)
    (save-excursion
      (save-restriction
        (narrow-to-region
         (window-start)
         (window-end))
        (goto-char (point-min))
        (setq pt (point))
        (while (progn (widget-forward 1)
                      (> (point) pt))
          (setq pt (point))
          (when (get-char-property (point) 'button)
            (push (point) candidates)))))
    (nreverse candidates)))

(declare-function outline-invisible-p "outline")
(defvar org-any-link-re)
(defun ali--org-collect-references ()
  (let ((end (window-end))
        points)
    (save-excursion
      (goto-char (window-start))
      (while (re-search-forward org-any-link-re end t)
        ;; Check that the link is visible. Look at the last character
        ;; position in the link ("...X]]") to cover links with and
        ;; without a description.
        (when (not (outline-invisible-p (- (match-end 0) 3)))
          (push (match-beginning 0) points)))
      (nreverse points))))

(defun ali--addr-collect-references ()
  (let (candidates)
    (dolist (overlay (overlays-in (window-start) (window-end)))
      (if (overlay-get overlay 'goto-address)
          (push (overlay-start overlay) candidates)))
    (nreverse candidates)))

;;* Bindings
(defvar eww-link-keymap)
(defvar eww-mode-map)
(defvar custom-mode-map)

;;;###autoload
(defun ace-link-setup-default (&optional key)
  "Bind KEY to appropriate functions in appropriate keymaps."
  (setq key (or key "o"))
  (eval-after-load "info"
    `(define-key Info-mode-map ,key 'ace-link-info))
  (eval-after-load "compile"
    `(define-key compilation-mode-map ,key 'ace-link-compilation))
  (eval-after-load "help-mode"
    `(define-key help-mode-map ,key 'ace-link-help))
  (eval-after-load "woman"
    `(define-key woman-mode-map ,key 'ace-link-woman))
  (eval-after-load "eww"
    `(progn
       (define-key eww-link-keymap ,key 'ace-link-eww)
       (define-key eww-mode-map ,key 'ace-link-eww)))
  (eval-after-load 'cus-edit
    `(progn
       (define-key custom-mode-map ,key 'ace-link-custom))))

(provide 'ace-link)

;;; ace-link.el ends here
