;;; navigation-util.el --- Navigation utilities -*- lexical-binding: t; -*-

;;; Commentary:
;; C-r で「タブローカルのバッファリスト (bufferlo)」と「recentf」をトグルし、
;; C-t で選択中の候補の位置から find-file を開始する。

;;; Code:

(defvar my/c-r-state 'recentf "State of C-r toggle: 'recentf or 'local.")

(defun my/minibuffer-exit-run (func &rest args)
  "minibuffer を閉じ、抜けた直後に FUNC を ARGS で実行する。
minibuffer 内から別の補完 UI へ開き直すため、exit 後の次のイベント
ループまで実行を遅らせる。
以前は 0.05 秒待っていたが、その待ち時間に届いたキー入力が
`minibufferp' で「minibuffer の外」と誤判定され、C-r 連打で開く UI が
安定しない原因になっていた (2026-07-31 に 0 へ短縮)。"
  (run-at-time 0 nil (lambda () (apply func args)))
  (delete-minibuffer-contents)
  (ignore-errors (exit-minibuffer)))

(defun my/find-file-in-dir (dir)
  "Start interactive `find-file` with default directory set to DIR."
  (let ((default-directory dir)) (call-interactively 'find-file)))

(defun my/local-buffer-or-recentf ()
  "Toggle between recentf and tab-local (bufferlo) buffer list."
  (interactive)
  (if (not (minibufferp))
      (progn (setq my/c-r-state 'local) (call-interactively 'bufferlo-switch-to-buffer))
    (setq my/c-r-state (if (eq my/c-r-state 'recentf) 'local 'recentf))
    (my/minibuffer-exit-run
     (if (eq my/c-r-state 'recentf) (if (fboundp 'consult-recentf) #'consult-recentf #'consult-buffer)
       #'bufferlo-switch-to-buffer))))

(defun my/candidate-directory (cand)
  "補完候補 CAND から find-file の起点ディレクトリを求める。決まらなければ nil。
候補の形だけで判定するので、recentf とバッファリストのどちらを開いて
いても同じ意味で動く。
以前は `my/c-r-state' で分岐していたが、状態変数と実際に開いている UI が
ズレるとバッファ名を `expand-file-name' に渡してしまい、カーソル位置と
無関係なディレクトリ (default-directory 基準) を返していた。"
  (when (and (stringp cand) (not (string-empty-p cand)))
    (cond
     ;; recentf / consult-recentf の候補。"~/..." も絶対パス扱いになる
     ((file-name-absolute-p cand)
      (file-name-directory (expand-file-name cand)))
     ;; bufferlo-switch-to-buffer の候補 (バッファ名)
     ((get-buffer cand)
      (buffer-local-value 'default-directory (get-buffer cand))))))

(defun my/recentf-directories ()
  "recentf に含まれるディレクトリを重複なしで返す。"
  (let ((files (and (boundp 'recentf-list) recentf-list)))
    (delete-dups (seq-filter #'file-directory-p
                             (mapcar #'file-name-directory files)))))

(defun my/vertico-select-directory-from-candidates ()
  "選択中の候補の位置から find-file を開始する。
候補から起点が決められないときは recentf のディレクトリ一覧から選ぶ。"
  (interactive)
  (unless (minibufferp) (user-error "Not in minibuffer"))
  (let ((dir (my/candidate-directory (vertico--candidate))))
    (if dir
        (my/minibuffer-exit-run #'my/find-file-in-dir dir)
      (let ((dirs (my/recentf-directories)))
        (if (null dirs)
            (message "No dirs found")
          (my/minibuffer-exit-run
           (lambda (ds) (my/find-file-in-dir
                         (if (= (length ds) 1) (car ds)
                           (completing-read "Select directory: " ds nil t))))
           dirs))))))

(provide 'navigation-util)
;;; navigation-util.el ends here
