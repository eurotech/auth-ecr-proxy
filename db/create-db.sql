CREATE TABLE IF NOT EXISTS `groups` (
  `id_gr`   INT         PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `name`    varchar(30) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `users` (
  `id_us`       INT         PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `username` varchar(15) NOT NULL DEFAULT '',
  `password` varchar(56) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `uri` (
  `id_ur` INT          PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `uri`   varchar(50)  NOT NULL DEFAULT '',
  `name`  varchar(50)  NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `groups_uri_ref` (
  `id_gr` INT          NOT NULL,
  `id_ur` INT          NOT NULL,
   foreign key(id_gr)  references groups(id_gr),
   foreign key(id_ur)  references uri(id_ur)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `groups_users_ref` (
  `id_gr` INT          NOT NULL,
  `id_us` INT          NOT NULL,
   foreign key(id_gr)  references groups(id_gr),
   foreign key(id_us)  references users(id_us)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
