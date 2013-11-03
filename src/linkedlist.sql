-- create linked list table
-- it contains several lists identified by list containing noderefs
-- and pointing to their successors if any, null otherwise
CREATE TABLE linkedlist (
  id      SERIAL PRIMARY KEY,
  list    INT,
  noderef INT,
  next    INT REFERENCES linkedlist (id),
  UNIQUE (list, id)
);

-- insert data into the table
DO $$
DECLARE
  v_generated_id INT;
BEGIN
  -- list 1
  INSERT INTO linkedlist VALUES (DEFAULT, 1, 4, NULL)
  RETURNING id
    INTO v_generated_id;
  INSERT INTO linkedlist VALUES (DEFAULT, 1, 3, v_generated_id)
  RETURNING id
    INTO v_generated_id;
  INSERT INTO linkedlist VALUES (DEFAULT, 1, 2, v_generated_id)
  RETURNING id
    INTO v_generated_id;
  INSERT INTO linkedlist VALUES (DEFAULT, 1, 1, v_generated_id)
  RETURNING id
    INTO v_generated_id;

  -- list 2
  INSERT INTO linkedlist VALUES (DEFAULT, 2, 2, NULL)
  RETURNING id
    INTO v_generated_id;
  INSERT INTO linkedlist VALUES (DEFAULT, 2, 1, v_generated_id)
  RETURNING id
    INTO v_generated_id;
END $$;

-- view including list positions
CREATE VIEW linkedlistpos_v AS
    WITH RECURSIVE linkedlistpos(id, list, noderef, next, pos) AS (
      SELECT
        ll.*,
        0
      FROM linkedlist ll
      WHERE ll.next IS null
      UNION ALL
      SELECT
        ll.*,
        llp.pos + 1
      FROM linkedlist ll INNER JOIN linkedlistpos llp
          ON ll.next = llp.id AND ll.list = llp.list
    ) SELECT
      *
    FROM linkedlistpos;

-- get whole linked list in list order
SELECT
  llpv.id,
  llpv.noderef,
  llpv.next
FROM linkedlistpos_v llpv
WHERE llpv.list = 1
ORDER BY llpv.pos DESC;

-- length of list
CREATE OR REPLACE FUNCTION linkedlist_length(list_id INTEGER)
  RETURNS INTEGER AS $$
DECLARE list_length INTEGER;
BEGIN
  RETURN (SELECT
            count(*)
          FROM linkedlist ll
          WHERE ll.list = list_id);
END $$ LANGUAGE plpgsql;

-- insert node before reference, create new one if it doesn't exist
CREATE OR REPLACE FUNCTION linkedlist_insert_before(list_id INTEGER, before_id INTEGER, new_node INTEGER)
  RETURNS VOID AS $$
DECLARE v_new_id INTEGER;
BEGIN
  -- insert new node
  INSERT INTO linkedlist VALUES (DEFAULT, list_id, new_node, before_id)
  RETURNING id
    INTO v_new_id;
  -- update old predecessor
  UPDATE linkedlist
  SET next = v_new_id
  WHERE next = before_id AND noderef <> new_node AND list = list_id;
END $$ LANGUAGE plpgsql VOLATILE;

-- insert node after reference, create new one if it doesn't exist
CREATE OR REPLACE FUNCTION linkedlist_insert_after(list_id INTEGER, after_id INTEGER, new_node INTEGER)
  RETURNS VOID AS $$
DECLARE v_new_id INTEGER;
BEGIN
-- insert new node
  INSERT INTO linkedlist VALUES (DEFAULT, list_id, new_node, (SELECT
                                                                ll.next
                                                              FROM linkedlist ll
                                                              WHERE ll.list = list_id AND ll.id = after_id))
  RETURNING id
    INTO v_new_id;
-- update old predecessor
  UPDATE linkedlist
  SET next = v_new_id
  WHERE id = after_id AND list = list_id;
END $$ LANGUAGE plpgsql VOLATILE;

-- move node before other
CREATE OR REPLACE FUNCTION linkedlist_move_before(list_id INTEGER, node_id INTEGER, before_id INTEGER)
  RETURNS VOID AS $$
BEGIN
-- update node before node_id to point to node_id's next
  UPDATE linkedlist
  SET next = (SELECT
                ll.next
              FROM linkedlist ll
              WHERE ll.list = list_id AND ll.id = node_id)
  WHERE next = node_id AND list = list_id;
-- update node_id's next column
  UPDATE linkedlist
  SET next = before_id
  WHERE list = list_id AND id = node_id;
-- update node before before_id to point to node_id
  UPDATE linkedlist
  SET next = node_id
  WHERE list = list_id AND next = before_id AND id <> node_id;
END $$ LANGUAGE plpgsql VOLATILE;

-- move node after other node
CREATE OR REPLACE FUNCTION linkedlist_move_after(list_id INTEGER, node_id INTEGER, after_id INTEGER)
  RETURNS VOID AS $$
BEGIN
  -- update node before node_id's next field
  UPDATE linkedlist
  SET next = (SELECT
                ll.next
              FROM linkedlist ll
              WHERE ll.list = list_id AND ll.id = node_id)
  WHERE list = list_id AND next = node_id;
  -- update node_id's next field
  UPDATE linkedlist
  SET next = (SELECT
                ll.next
              FROM linkedlist ll
              WHERE ll.list = list_id AND ll.id = after_id)
  WHERE list = list_id AND id = node_id;
  -- update after_id's next field
  UPDATE linkedlist
  SET next = node_id
  WHERE list = list_id AND id = after_id;
END $$ LANGUAGE plpgsql VOLATILE;

-- delete node
CREATE OR REPLACE FUNCTION linkedlist_delete(list_id INTEGER, node_id INTEGER)
  RETURNS VOID AS $$
BEGIN
  -- set next of node before node_id to node_id's next
  UPDATE linkedlist
  SET next = (SELECT
                ll.next
              FROM linkedlist ll
              WHERE ll.list = list_id AND ll.id = node_id)
  WHERE ll.list = list_id AND ll.next = node_id;
  -- delete node_id
  DELETE FROM linkedlist
  WHERE list = list_id AND id = node_id;
END $$ LANGUAGE plpgsql VOLATILE;