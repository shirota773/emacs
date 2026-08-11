;;; my-markdown-fold.el --- 閲覧モードで <details> を畳む -*- lexical-binding: t; -*-

;; ★ 試作 (2026-08-11)。うまくいかなければファイルごと消してよい。
;;
;; Notion のトグルリストにあたるものを閲覧モードで作る。Markdown 側の記法は
;; GFM 標準の <details> をそのまま使う。プレビュー (HTML) では素で折りたためる
;; ので、Markdown・プレビュー・Emacs の三方で同じ書き方が通る。
;;
;;   <details><summary>畳んだときに見えるタイトル</summary>
;;
;;   開かないと見えない中身。
;;
;;   </details>
;;
;; 閲覧モードでは
;;
;;   ▶ 畳んだときに見えるタイトル      … RET かクリックで開く
;;   ▼ 畳んだときに見えるタイトル      … 開いた状態。もう一度で閉じる
;;
;; になる。`<details open>' と書けば最初から開いた状態にする (HTML と同じ)。
;;
;; 実装は overlay 2 枚。開始行を `display' で「▶ タイトル」に差し替えるものと、
;; 中身を `invisible' で隠すもの。開閉はこの 2 枚を書き換えるだけで、バッファの
;; 中身には触らない。

(require 'markdown-mode)

(defgroup my/markdown-fold nil
  "閲覧モードで <details> を折りたたむ。"
  :group 'markdown)

(defcustom my/markdown-fold-closed-marker "▶ "
  "畳んでいるときに見出しの前に出す印。"
  :type 'string
  :group 'my/markdown-fold)

(defcustom my/markdown-fold-open-marker "▼ "
  "開いているときに見出しの前に出す印。"
  :type 'string
  :group 'my/markdown-fold)

(defface my/markdown-fold-title
  '((t :inherit markdown-header-face-4))
  "折りたたみのタイトルのフェイス。"
  :group 'my/markdown-fold)

(defconst my/markdown-fold--open-re "<details\\([ \t]+open\\)?[ \t]*>"
  "開始タグ。グループ 1 があれば最初から開いた状態にする。")

(defconst my/markdown-fold--close-re "</details[ \t]*>")

(defconst my/markdown-fold--summary-re "<summary[^>]*>\\(.*?\\)</summary[ \t]*>")

(defvar my/markdown-fold-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'my/markdown-fold-toggle)
    (define-key map (kbd "TAB") #'my/markdown-fold-toggle)
    (define-key map [mouse-1] #'my/markdown-fold-toggle)
    map)
  "折りたたみの見出しの上でだけ効くキーマップ。")

;;; 開閉 ----------------------------------------------------------------------

(defun my/markdown-fold--apply (header open)
  "HEADER (見出しの overlay) の状態を OPEN にする。"
  (let ((body (overlay-get header 'my/markdown-fold-body))
        (title (overlay-get header 'my/markdown-fold-title)))
    (overlay-put header 'my/markdown-fold-open open)
    (overlay-put header 'display
                 (concat (if open
                             my/markdown-fold-open-marker
                           my/markdown-fold-closed-marker)
                         title))
    (when (overlayp body)
      (overlay-put body 'invisible (not open)))))

(defun my/markdown-fold--at (pos)
  "POS にある折りたたみの見出し overlay を返す。無ければ nil。"
  (seq-find (lambda (o) (overlay-get o 'my/markdown-fold-body))
            (overlays-at pos)))

(defun my/markdown-fold-toggle (&optional event)
  "ポイント (またはクリック位置) の折りたたみを開閉する。"
  (interactive (list last-nonmenu-event))
  ;; マウスイベントかどうかは (and event (listp event)) で見る。(listp nil) は t
  ;; なので listp だけで判定すると、キー起動のときに合成 posn が返ってポイントが
  ;; 飛ぶ (pitfall-elisp-listp-nil-is-true-so-nil-events-become-synthetic-posn)
  (let* ((pos (if (and event (listp event))
                  (posn-point (event-start event))
                (point)))
         (header (and pos (my/markdown-fold--at pos))))
    (if (null header)
        (user-error "ここには折りたたみが無い")
      (my/markdown-fold--apply
       header (not (overlay-get header 'my/markdown-fold-open))))))

;;; 組み立て ------------------------------------------------------------------

(defun my/markdown-fold--title (line-beg line-end)
  "LINE-BEG..LINE-END から <summary> の中身をフェイスごと取り出す。
見つからなければ nil。"
  (save-excursion
    (goto-char line-beg)
    (when (re-search-forward my/markdown-fold--summary-re line-end t)
      (let ((s (buffer-substring (match-beginning 1) (match-end 1))))
        (add-face-text-property 0 (length s) 'my/markdown-fold-title nil s)
        s))))

(defun my/markdown-fold-remove ()
  "このバッファに張った折りたたみの overlay を全部消す。"
  (interactive)
  (remove-overlays (point-min) (point-max) 'my/markdown-fold t))

(defun my/markdown-fold-refresh ()
  "バッファ中の <details> を折りたたみに差し替える。"
  (interactive)
  (my/markdown-fold-remove)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward my/markdown-fold--open-re nil t)
      (let* ((open-p (match-beginning 1))
             (head-beg (line-beginning-position))
             (head-end (line-end-position))
             (title (my/markdown-fold--title head-beg head-end)))
        (if (null title)
            ;; <summary> の無い <details> は畳む手がかりが無いので触らない
            (forward-line 1)
          (let ((close (save-excursion
                         (when (re-search-forward my/markdown-fold--close-re nil t)
                           (line-end-position)))))
            (if (null close)
                (forward-line 1)
              (let ((header (make-overlay head-beg head-end))
                    ;; 中身は見出しの行末から </details> の行末まで。閉じタグの
                    ;; 行ごと隠すので、開いていても </details> は見えない
                    (body (make-overlay head-end close)))
                (dolist (ov (list header body))
                  (overlay-put ov 'my/markdown-fold t)
                  (overlay-put ov 'evaporate t))
                (overlay-put header 'my/markdown-fold-body body)
                (overlay-put header 'my/markdown-fold-title title)
                (overlay-put header 'keymap my/markdown-fold-map)
                (overlay-put header 'mouse-face 'highlight)
                (overlay-put header 'help-echo "RET / クリックで開閉")
                ;; mouse-1 を自前で受けるので、リンク扱いにさせない
                (overlay-put header 'follow-link nil)
                (my/markdown-fold--apply header (and open-p t))
                (goto-char close)))))))))

(defun my/markdown-fold-setup ()
  "閲覧モードのセットアップから呼ぶ入口。<details> が無ければ何もしない。"
  (when (save-excursion
          (goto-char (point-min))
          (re-search-forward my/markdown-fold--open-re nil t))
    (my/markdown-fold-refresh)
    ;; overlay はメジャーモードを変えても残るので、編集モードに戻るときに片付ける
    (add-hook 'change-major-mode-hook #'my/markdown-fold-remove nil t)))

(provide 'my-markdown-fold)
;;; my-markdown-fold.el ends here
