use cite_tables;

load data local infile '/Users/ada/cite_collections_rails/data/Perseus Authors Collection.csv' into table authors fields terminated by ','
enclosed by '"'
lines terminated by '\n'
(urn, authority_name, canonical_id, mads_file, alt_ids, related_works, urn_status, redirect_to, created_by, edited_by);

load data local infile '/Users/ada/cite_collections_rails/data/Perseus Work Collection.csv' into table cite_tables.works fields terminated by ','
enclosed by '"'
lines terminated by '\n'
(urn, work, title_eng, orig_lang, notes, urn_status, redirect_to, created_by, edited_by);

load data local infile '/Users/ada/cite_collections_rails/data/Perseus Textgroup Collection.csv' into table textgroups fields terminated by ','
enclosed by '"'
lines terminated by '\n'
(urn, textgroup, groupname_eng, has_mads, mads_possible, notes, urn_status, redirect_to, created_by, edited_by);

load data local infile '/Users/ada/cite_collections_rails/data/Perseus Version Collection.csv' into table versions fields terminated by ','
enclosed by '"'
lines terminated by '\n'
(urn, version, label_eng, desc_eng, ver_type, has_mods, urn_status, redirect_to, member_of, created_by, edited_by);