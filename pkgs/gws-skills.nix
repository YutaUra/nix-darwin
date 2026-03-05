{ lib, fetchFromGitHub }:

let
  src = fetchFromGitHub {
    owner = "googleworkspace";
    repo = "cli";
    rev = "6ed836c81c6ed4834a434adc40a14bb2e6f3f3b9";
    hash = "sha256-Ar21dUPuHoJY+z1I80ckT5EcIrpGrmMpi2VAXpBSDwA=";
  };

  selectedSkills = [
    # 共通ユーティリティ（他の skill が参照する）
    "gws-shared"

    # Gmail
    "gws-gmail"
    "gws-gmail-send"
    "gws-gmail-triage"
    "gws-gmail-watch"

    # Drive
    "gws-drive"
    "gws-drive-upload"

    # Docs / Sheets / Slides
    "gws-docs"
    "gws-docs-write"
    "gws-sheets"
    "gws-sheets-read"
    "gws-sheets-append"
    "gws-slides"

    # Forms
    "gws-forms"

    # Persona
    "persona-content-creator"
    "persona-customer-support"
    "persona-event-coordinator"
    "persona-exec-assistant"
    "persona-hr-coordinator"
    "persona-it-admin"
    "persona-project-manager"
    "persona-researcher"
    "persona-sales-ops"
    "persona-team-lead"

    # Recipe（コアサービス関連のみ）
    "recipe-create-gmail-filter"
    "recipe-forward-labeled-emails"
    "recipe-label-and-archive-emails"
    "recipe-search-and-export-emails"
    "recipe-send-personalized-emails"
    "recipe-send-team-announcement"
    "recipe-batch-reply-to-emails"
    "recipe-save-email-attachments"
    "recipe-save-email-to-doc"
    "recipe-create-vacation-responder"
    "recipe-draft-email-from-doc"
    "recipe-email-drive-link"
    "recipe-find-large-files"
    "recipe-organize-drive-folder"
    "recipe-batch-rename-files"
    "recipe-bulk-download-folder"
    "recipe-share-folder-with-team"
    "recipe-create-shared-drive"
    "recipe-transfer-file-ownership"
    "recipe-watch-drive-changes"
    "recipe-create-doc-from-template"
    "recipe-share-doc-and-notify"
    "recipe-backup-sheet-as-csv"
    "recipe-compare-sheet-tabs"
    "recipe-copy-sheet-for-new-month"
    "recipe-create-expense-tracker"
    "recipe-generate-report-from-sheet"
    "recipe-sync-contacts-to-sheet"
    "recipe-collect-form-responses"
    "recipe-create-feedback-form"
    "recipe-create-presentation"
  ];

  # 各 skill の SKILL.md を home.file 用の attrset にマッピング
  skillFiles = builtins.listToAttrs (map (name: {
    name = ".claude/skills/${name}/SKILL.md";
    value = { source = "${src}/skills/${name}/SKILL.md"; };
  }) selectedSkills);
in
{
  inherit skillFiles;
}
