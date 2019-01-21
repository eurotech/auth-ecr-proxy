CREATE TABLE IF NOT EXISTS `http_groups` (
  `id`   INT         PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `name` varchar(15) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `http_users` (
  `id`       INT         PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `username` varchar(15) NOT NULL DEFAULT '',
  `password` varchar(56) NOT NULL DEFAULT '',
  `group_id` INT         NOT NULL,
   foreign key(group_id) references http_groups(id)  
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `uri_ref` (
  `id`       INT          PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `uri`      varchar(50)  NOT NULL DEFAULT '',
  `group_id` INT          NOT NULL,
   foreign key(group_id) references http_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

