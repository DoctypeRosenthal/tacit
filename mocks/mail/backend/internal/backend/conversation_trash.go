package backend

import (
	"context"
	"database/sql"
	"encoding/json"
)

func (s *Store) TrashConversation(ctx context.Context, account, conversation string) (string, error) {
	if account == "" || conversation == "" {
		return "", ErrInvalid
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer tx.Rollback()
	rows, err := tx.QueryContext(ctx, "SELECT id, mailbox FROM messages WHERE account_id=? AND conversation_id=? AND mailbox NOT IN ('Trash','Drafts','Outbox')", account, conversation)
	if err != nil {
		return "", err
	}
	original := map[string]string{}
	for rows.Next() {
		var id, folder string
		if err = rows.Scan(&id, &folder); err != nil {
			rows.Close()
			return "", err
		}
		original[id] = folder
	}
	rows.Close()
	if err = rows.Err(); err != nil {
		return "", err
	}
	if len(original) == 0 {
		return "", ErrNotFound
	}
	for id := range original {
		m, e := read(ctx, tx, id)
		if e != nil {
			return "", e
		}
		m.TrashOrigin = m.Mailbox
		m.Mailbox = "Trash"
		if e = s.write(ctx, tx, m); e != nil {
			return "", e
		}
	}
	token := id()
	data, err := json.Marshal(original)
	if err != nil {
		return "", err
	}
	if _, err = tx.ExecContext(ctx, "INSERT INTO metadata(key,value) VALUES(?,?)", "trash-undo:"+token, string(data)); err != nil {
		return "", err
	}
	return token, tx.Commit()
}

func (s *Store) UndoConversationTrash(ctx context.Context, token string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var data string
	key := "trash-undo:" + token
	if err = tx.QueryRowContext(ctx, "SELECT value FROM metadata WHERE key=?", key).Scan(&data); err != nil {
		if err == sql.ErrNoRows {
			return ErrNotFound
		}
		return err
	}
	var original map[string]string
	if err = json.Unmarshal([]byte(data), &original); err != nil {
		return err
	}
	for id, folder := range original {
		m, e := read(ctx, tx, id)
		if e != nil {
			return e
		}
		if m.Mailbox != "Trash" {
			return ErrConflict
		}
		m.Mailbox = folder
		m.TrashOrigin = ""
		if e = s.write(ctx, tx, m); e != nil {
			return e
		}
	}
	if _, err = tx.ExecContext(ctx, "DELETE FROM metadata WHERE key=?", key); err != nil {
		return err
	}
	return tx.Commit()
}

func (s *Store) DeleteTrashedMessage(ctx context.Context, id string) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	m, err := read(ctx, tx, id)
	if err != nil {
		return err
	}
	if m.Mailbox != "Trash" {
		return ErrConflict
	}
	for _, statement := range []string{
		"DELETE FROM outbox WHERE message_id=? AND state IN ('sent','cancelled')",
		"DELETE FROM search WHERE message_id=?",
		"DELETE FROM messages WHERE id=?",
	} {
		if _, err = tx.ExecContext(ctx, statement, id); err != nil {
			return err
		}
	}
	return tx.Commit()
}
