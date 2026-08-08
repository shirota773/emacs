;;; my-defuns.el --- Miscellaneous custom functions -*- lexical-binding: t; -*-

;; =============================================================================
;; 1. File & Application Utilities
;; =============================================================================

;; OS 既定のアプリケーションでファイルを開く (2026-07-31 に統合)。
;; 以前は同じことをする実装が 3 つに散っていた: ここの
;; open-file-in-external-app、05_dired.el の my/dired-open-externally、
;; パッケージの crux-open-with。プラットフォーム分岐も 2 箇所に重複し、
;; さらに前 2 つはキーに繋がっていなかった。分岐を my/open-externally に集約。
;; crux-open-with は Windows 分岐を持たない (毎回コマンド名を聞かれる) ため
;; 採用しない。
;;
;; 入口は 3 つ (2026-08-01 に最小構成へ整理):
;;   C-c o                          カレントを既定アプリで開く
;;   M-x my/open-externally-with-app  カレントをアプリを選んで開く
;;   M-o a                          embark の候補をアプリを選んで開く
;; ファイルを選んで開く版 (旧 my/open-externally-select、C-c O) は、
;; 対象が決まらないときの read-file-name フォールバックごと外した。

(defun my/open-externally (file &optional app)
  "FILE を OS 既定のアプリケーションで開く。
APP を指定するとそのアプリで開く (macOS はアプリ名、Windows は実行ファイル、
Linux はコマンド名)。md の既定がエディタでもブラウザやビューアーで見たい、
といった用途のため。"
  (unless file
    (user-error "対象のファイルがありません"))
  ;; リモート判定は file-exists-p より必ず先に行う。TRAMP パスに
  ;; file-exists-p を呼ぶと実接続を試みて待たされるが、file-remote-p は
  ;; 文字列を見るだけで接続しない。
  (when (file-remote-p file)
    (user-error "リモートファイルは既定アプリで開けません: %s" file))
  (let ((path (expand-file-name file)))
    (unless (file-exists-p path)
      (user-error "ファイルが見つかりません: %s" path))
    (cond
     (darwin-p     (if app
                       (call-process "open" nil 0 nil "-a" app path)
                     (call-process "open" nil 0 nil path)))
     (windows-nt-p (if app
                       (w32-shell-execute "open" app path)
                     (w32-shell-execute "open" path)))
     (t            (if app
                       (call-process app nil 0 nil path)
                     (call-process "xdg-open" nil 0 nil path))))))

(defvar my/open-external-app-history nil
  "`my/open-externally' でアプリを選んだ履歴。前回選んだものが上に出る。")

(defun my/open-external-app-candidates ()
  "アプリ指定の補完候補を返す。
macOS はインストール済みの .app を列挙する。候補を固定リストで持たないのは
メンテが要るうえ、vertico + orderless なら数文字で絞れるため。
Windows/Linux は列挙する手段が一定しないので候補なし (自由入力)。"
  (when darwin-p
    (let (apps)
      (dolist (dir '("/Applications" "/System/Applications"
                     "/System/Applications/Utilities" "~/Applications"))
        (let ((dir (expand-file-name dir)))
          (when (file-directory-p dir)
            (dolist (f (directory-files dir nil "\\.app\\'" t))
              (push (file-name-sans-extension f) apps)))))
      (sort (delete-dups apps) #'string<))))

(defun my/open-externally--read-app ()
  "開くアプリを選ぶ。候補に無いものも入力できる。"
  (completing-read "アプリ: " (my/open-external-app-candidates)
                   nil nil nil 'my/open-external-app-history))

(defun my/open-externally--target ()
  "既定アプリで開く対象を返す。決まらなければ nil。
dired ならポイント下のファイル、そうでなければ訪問中のファイル。"
  (if (derived-mode-p 'dired-mode)
      (dired-get-filename nil t)
    buffer-file-name))

(defun my/open-externally--open-current (app)
  "現在の対象を APP (nil なら既定アプリ) で開く。
既定アプリはディスク上の内容を読むため、未保存の変更があれば先に保存を尋ねる。"
  (let ((file (or (my/open-externally--target)
                  (user-error "このバッファはファイルを訪問していません"))))
    (when (and (equal file buffer-file-name)
               (buffer-modified-p)
               (y-or-n-p "未保存の変更があります。保存してから開きますか? "))
      (save-buffer))
    (my/open-externally file app)))

(defun my/open-externally-dwim ()
  "現在の対象を OS 既定のアプリケーションで開く。
dired ならポイント下、そうでなければ訪問中のファイル。"
  (interactive)
  (my/open-externally--open-current nil))

(defun my/open-externally-with-app ()
  "現在の対象を、アプリを選んで開く。
md の既定がエディタでも、ブラウザや専用ビューアーで見たいときのため。
キーには割り当てず M-x から呼ぶ (C-u を挟む 3 ストロークより速いため)。"
  (interactive)
  (my/open-externally--open-current (my/open-externally--read-app)))

(defun my/embark-open-with-app (file)
  "FILE をアプリを選んで開く。`embark-act' (M-o a) から呼ぶ用。
embark 標準の `embark-open-externally' (M-o x) は既定アプリ固定なので、
アプリを選べる版として足す。キーの割当は 02_completion.el 側。
interactive spec の \"f\" は embark が対象を流し込むために必要。"
  (interactive "fファイル: ")
  (my/open-externally file (my/open-externally--read-app)))

(defun my/reveal-in-file-manager (&optional file)
  "FILE を OS のファイラで選択状態にして表示する (C-c O)。
FILE 省略時は dired ならポイント下、そうでなければ訪問中のファイル。
`my/open-externally' (C-c o) が「開く」のに対し、こちらは「置き場所を見せる」。
AirDrop や共有メニューなど、OS のファイラ側でしかできない操作に渡すため。"
  (interactive)
  (let* ((file (or file (my/open-externally--target)
                   (user-error "対象のファイルがありません")))
         (path (expand-file-name file)))
    ;; 理由は `my/open-externally' と同じ。file-remote-p は接続しない。
    (when (file-remote-p path)
      (user-error "リモートファイルは表示できません: %s" path))
    (unless (file-exists-p path)
      (user-error "ファイルが見つかりません: %s" path))
    (cond
     (darwin-p     (call-process "open" nil 0 nil "-R" path))
     ;; explorer は区切りがバックスラッシュでないとファイルを選択してくれない。
     ;; また /select, と パスの間に空白を入れると解釈されない。
     (windows-nt-p (call-process "explorer" nil 0 nil
                                 (concat "/select," (subst-char-in-string ?/ ?\\ path))))
     ;; Linux は「選択状態で開く」の共通手段が無いので親ディレクトリを開く
     (t            (call-process "xdg-open" nil 0 nil
                                 (file-name-directory path))))))

(defun rename-file-and-buffer (new-name)
  "Renames both current buffer and file it's visiting to NEW-NAME."
  (interactive "sNew name: ")
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not filename)
        (message "Buffer '%s' is not visiting a file!" name)
      (if (get-buffer new-name)
          (message "A buffer named '%s' already exists!" new-name)
        (progn
          (rename-file filename new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil))))))

(defun reopen-with-sudo ()
  "Reopen current buffer-file with sudo using tramp."
  (interactive)
  (let ((file-name (buffer-file-name)))
    (if file-name
        (find-alternate-file (concat "/sudo::" file-name))
      (error "Cannot get a file name"))))

(defun revert-buffer-no-confirm ()
  "Revert buffer without confirmation."
  (interactive)
  (revert-buffer t t))

;; =============================================================================
;; 2. UI & Frame Utilities
;; =============================================================================

(defvar my/alpha-on-flag nil)
(defun my/alpha-toggle()
  (interactive)
  (if (equal my/alpha-on-flag t)
      (progn
        (set-frame-parameter nil 'alpha 98)
        (setq my/alpha-on-flag nil)
        (message "alpha-off"))
    (progn
      (set-frame-parameter nil 'alpha 85)
      (setq my/alpha-on-flag t)
      (message "alpha-on"))))

(defun my/get-buffer-create-junk ()
  (interactive)
  (switch-to-buffer (get-buffer-create "*junk*"))
  (emacs-lisp-mode))

(defvar my/monitor-alist
  '(("Built-in Retina Display" . ((top . 25) (left . 840) (width . 117) (height . 66)))
    ("LG HDR 4K" . ((top . 25) (left . 1550) (width . 206) (height . 90)))))

(defun my/adjust-frame-size-and-position ()
  (interactive)
  (let* ((monitor-name (cdr (assq 'name (frame-monitor-attributes))))
         (params (cdr (assoc monitor-name my/monitor-alist))))
    (when params
      (modify-frame-parameters nil params))))

;; =============================================================================
;; 3. Editing Utilities
;; =============================================================================

(defun my/dabbrev-expand-or-completing-read ()
  "Perform normal `dabbrev-expand` on the first call.
If executed consecutively, narrow down candidates with Vertico/completing-read."
  (interactive)
  (require 'dabbrev)
  (if (and (eq last-command 'my/dabbrev-expand-or-completing-read)
           (boundp 'dabbrev--last-expansion)
           dabbrev--last-expansion)
      ;; [Second consecutive execution]
      (let* ((abbrev dabbrev--last-abbreviation) ; Original input before expansion (e.g., "aaa")
             (expansion dabbrev--last-expansion) ; First expansion string (e.g., "aaaccc")
             ;; Accurately calculate the start position of the first expansion
             (start-pos (- (point) (length expansion)))
             ;; Set a marker at the start position (including buffer info)
             (abbrev-location (copy-marker start-pos))
             (success nil)
             (selected nil))
        ;; Clear dabbrev internal state (scan position, previous buffer, etc.) for a clean scan
        (dabbrev--reset-global-variables)
        ;; Revert the first expansion back to the original input
        (delete-region start-pos (point))
        (insert abbrev)
        ;; Respect user case-fold settings
        (let* ((ignore-case (if (eq dabbrev-case-fold-search 'case-fold-search)
                                case-fold-search
                              dabbrev-case-fold-search))
               ;; Retrieve expansions from all buffers and remove duplicates
               (candidates (delete-dups (dabbrev--find-all-expansions abbrev ignore-case))))
          (if (null candidates)
              (progn
                (set-marker abbrev-location nil)
                (message "No dabbrev candidates found for \"%s\"" abbrev))
            (unwind-protect
                (progn
                  ;; Launch Vertico (completing-read) to select a candidate
                  (setq selected (completing-read (format "Dabbrev (%s): " abbrev)
                                                   candidates nil t abbrev))
                  (setq success t))
              ;; Cleanup process (always run on both success and cancellation)
              ;; Safely perform buffer operations only on the marker's buffer
              (let ((target-buf (marker-buffer abbrev-location)))
                (when (buffer-live-p target-buf)
                  (with-current-buffer target-buf
                    (if success
                        ;; [On successful selection]
                        (progn
                          (delete-region abbrev-location (point))
                          (insert selected)
                          (setq dabbrev--last-expansion nil))
                      ;; [On cancellation (C-g)] Restore back to the original prefix
                      (delete-region abbrev-location (point))
                      (insert abbrev)
                      (message "Dabbrev selection cancelled. Restored to \"%s\"" abbrev)))))
              ;; Release the marker to help garbage collection
              (set-marker abbrev-location nil)))))
    ;; [First execution] Call standard dabbrev-expand
    (dabbrev-expand nil)))

(defun move-to-mark ()
  (interactive)
  (let ((pos (point)))
    (goto-char (mark))
    (push-mark pos)))

(defun switch-to-buffer-extension (prompt)
  (interactive
   (list (read-buffer "Switch to buffer: " (other-buffer (current-buffer)))))
  (switch-to-buffer prompt))

(provide 'my-defuns)
