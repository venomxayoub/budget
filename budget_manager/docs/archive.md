delete:
    - add delete functionlity to entries, add a delete button to the details view, once clicked the entry is soft deleted, add a new field to expense and income entries called deleted_at add timestampt when deleted and update updated_at as well deletion is an update.
archive:
    - add new link to the sidebar for archive.
    - achive shows all entries that were soft deleted, same style of listing as the expense/income view
    - we can open entry detail and have the option to restore or delete forever

both archive deletion and restortion and expense/icome entry deletion is without confirmation, no confirmation model is needed 