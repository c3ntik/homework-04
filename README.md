# homework-04

### Определение алгоритма с наилучшим сжатием

  Смотрим список всех дисков, которые есть в виртуальной машине: lsblk
      
    NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    sda      8:0    0  512M  0 disk 
    sdb      8:16   0  512M  0 disk 
    sdc      8:32   0  512M  0 disk 
    sdd      8:48   0  512M  0 disk 
    sde      8:64   0  512M  0 disk 
    sdf      8:80   0  512M  0 disk 
    sdg      8:96   0  512M  0 disk 
    sdh      8:112  0  512M  0 disk 
    sdi      8:128  0   40G  0 disk 
    -sdi1   8:129  0   40G  0 part /
    
    
   Создаём пул из двух дисков в режиме RAID 1: `zpool create otus1 mirror /dev/sda /dev/sdb`
   
   Создадим ещё 3 пула:
   
    zpool create otus2 mirror /dev/sdc /dev/sdd
    zpool create otus3 mirror /dev/sde /dev/sdf
    zpool create otus4 mirror /dev/sdg /dev/sdh
    
   Смотрим информацию о пулах: zpool list
   
    NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
    otus1   480M   106K   480M        -         -     0%     0%  1.00x    ONLINE  -
    otus2   480M   106K   480M        -         -     0%     0%  1.00x    ONLINE  -
    otus3   480M   106K   480M        -         -     0%     0%  1.00x    ONLINE  -
    otus4   480M  91.5K   480M        -         -     0%     0%  1.00x    ONLINE  -

  Команда zpool status показывает информацию о каждом диске, состоянии
  сканирования и об ошибках чтения, записи и совпадения хэш-сумм. Команда
  zpool list показывает информацию о размере пула, количеству занятого и
  свободного места, дедупликации и т.д.
  
  Добавим разные алгоритмы сжатия в каждую файловую систему:
  
    Алгоритм lzjb: zfs set compression=lzjb otus1
    Алгоритм lz4: zfs set compression=lz4 otus2
    Алгоритм gzip: zfs set compression=gzip-9 otus3
    Алгоритм zle: zfs set compression=zle otus4

  Проверим, что все файловые системы имеют разные методы сжатия zfs get all | grep compression:
    otus1  compression           lzjb                   local
    otus2  compression           lz4                    local
    otus3  compression           gzip-9                 local
    otus4  compression           zle                    local
    
  Сжатие файлов будет работать только с файлами, которые были добавлены
  после включение настройки сжатия.
  Скачаем один и тот же текстовый файл во все пулы:
  
    for i in {1..4}; do wget -P /otus$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done
    
  Проверим, что файл был скачан во все пулы ls -l /otus*:
    /otus1:
    total 22015
    -rw-r--r--. 1 root root 40784369 Feb  2 09:01 pg2600.converter.log

    /otus2:
    total 17970
    -rw-r--r--. 1 root root 40784369 Feb  2 09:01 pg2600.converter.log

    /otus3:
    total 10948
    -rw-r--r--. 1 root root 40784369 Feb  2 09:01 pg2600.converter.log

    /otus4:
    total 39856
    -rw-r--r--. 1 root root 40784369 Feb  2 09:01 pg2600.converter.log

  Уже на этом этапе видно, что самый оптимальный метод сжатия у нас
  используется в пуле otus3
  
  Проверим, сколько места занимает один и тот же файл в разных пулах и
  проверим степень сжатия файлов zfs list:
    
    NAME    USED  AVAIL     REFER  MOUNTPOINT
    otus1  21.6M   330M     21.5M  /otus1
    otus2  17.6M   334M     17.6M  /otus2
    otus3  10.8M   341M     10.7M  /otus3
    otus4  39.0M   313M     38.9M  /otus4

    zfs get all | grep compressratio | grep -v ref
    otus1  compressratio         1.81x                  -
    otus2  compressratio         2.22x                  -
    otus3  compressratio         3.64x                  -
    otus4  compressratio         1.00x                  -
    
   Таким образом, у нас получается, что алгоритм gzip-9 самый эффективный по сжатию.

### Определение настроек пула

  Скачиваем архив в домашний каталог:
    wget -O archive.tar.gz --no-check-certificate ‘https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download’
    
    -rw-r--r--. 1 root root 7275140 Feb 15 15:51 archive.tar.gz
  Разархивируем его:
    tar -xzvf archive.tar.gz
    zpoolexport/
    zpoolexport/filea
    zpoolexport/fileb
    
  Проверим, возможно ли импортировать данный каталог в пул:
    zpool import -d zpoolexport/    
           pool: otus
         id: 6554193320433390805
      state: ONLINE
     action: The pool can be imported using its name or numeric identifier.
     config:

            otus                         ONLINE
              mirror-0                   ONLINE
                /root/zpoolexport/filea  ONLINE
                /root/zpoolexport/fileb  ONLINE

  Данный вывод показывает нам имя пула, тип raid и его состав.
  Сделаем импорт данного пула к нам в ОС:    
  
    zpool import -d zpoolexport/ otus
    zpool status
    
            pool: otus
       state: ONLINE
        scan: none requested
      config:

              NAME                         STATE     READ WRITE CKSUM
              otus                         ONLINE       0     0     0
                mirror-0                   ONLINE       0     0     0
                  /root/zpoolexport/filea  ONLINE       0     0     0
                  /root/zpoolexport/fileb  ONLINE       0     0     0

      errors: No known data errors

        pool: otus1
       state: ONLINE
        scan: none requested
      config:

              NAME        STATE     READ WRITE CKSUM
              otus1       ONLINE       0     0     0
                mirror-0  ONLINE       0     0     0
                  sda     ONLINE       0     0     0
                  sdb     ONLINE       0     0     0

      errors: No known data errors

  Команда zpool status выдаст нам информацию о составе импортированного пула
  Если у Вас уже есть пул с именем otus, то можно поменять его имя во время импорта: zpool import -d zpoolexport/ otus newotus
  Далее нам нужно определить настройки
  Запрос сразу всех параметров пула: zpool get all otus
  Запрос сразу всех параметром файловой системы: zfs get all otus
  
    zfs get all otus
    
    NAME  PROPERTY              VALUE                  SOURCE
    otus  type                  filesystem             -
    otus  creation              Fri May 15  4:00 2020  -
    otus  used                  2.04M                  -
    otus  available             350M                   -
    otus  referenced            24K                    -
    otus  compressratio         1.00x                  -
    otus  mounted               yes                    -
    otus  quota                 none                   default
    otus  reservation           none                   default
    otus  recordsize            128K                   local
    otus  mountpoint            /otus                  default
    otus  sharenfs              off                    default
    otus  checksum              sha256                 local
    otus  compression           zle                    local
    otus  atime                 on                     default
    otus  devices               on                     default
    otus  exec                  on                     default
    otus  setuid                on                     default
    otus  readonly              off                    default
    otus  zoned                 off                    default
    otus  snapdir               hidden                 default
    otus  aclinherit            restricted             default
    otus  createtxg             1                      -
    otus  canmount              on                     default
    otus  xattr                 on                     default
    otus  copies                1                      default
    otus  version               5                      -
    otus  utf8only              off                    -
    otus  normalization         none                   -
    otus  casesensitivity       sensitive              -
    otus  vscan                 off                    default
    otus  nbmand                off                    default
    otus  sharesmb              off                    default
    otus  refquota              none                   default
    otus  refreservation        none                   default
    otus  guid                  14592242904030363272   -
    otus  primarycache          all                    default
    otus  secondarycache        all                    default
    otus  usedbysnapshots       0B                     -
    otus  usedbydataset         24K                    -
    otus  usedbychildren        2.01M                  -
    otus  usedbyrefreservation  0B                     -
    otus  logbias               latency                default
    otus  objsetid              54                     -
    otus  dedup                 off                    default
    otus  mlslabel              none                   default
    otus  sync                  standard               default
    otus  dnodesize             legacy                 default
    otus  refcompressratio      1.00x                  -
    otus  written               24K                    -
    otus  logicalused           1020K                  -
    otus  logicalreferenced     12K                    -
    otus  volmode               default                default
    otus  filesystem_limit      none                   default
    otus  snapshot_limit        none                   default
    otus  filesystem_count      none                   default
    otus  snapshot_count        none                   default
    otus  snapdev               hidden                 default
    otus  acltype               off                    default
    otus  context               none                   default
    otus  fscontext             none                   default
    otus  defcontext            none                   default
    otus  rootcontext           none                   default
    otus  relatime              off                    default
    otus  redundant_metadata    all                    default
    otus  overlay               off                    default
    otus  encryption            off                    default
    otus  keylocation           none                   default
    otus  keyformat             none                   default
    otus  pbkdf2iters           0                      default
    otus  special_small_blocks  0                      default


  C помощью команды grep можно уточнить конкретный параметр, например:
    zfs get available otus
    NAME  PROPERTY   VALUE  SOURCE
    otus  available  350M   -
    
    zfs get readonly otus
    NAME  PROPERTY  VALUE   SOURCE
    otus  readonly  off     default

   По типу FS мы можем понять, что позволяет выполнять чтение и запись 
   Значение recordsize: zfs get recordsize otus
   
    zfs get recordsize otus
    NAME  PROPERTY    VALUE    SOURCE
    otus  recordsize  128K     local
    
  Тип сжатия (или параметр отключения): zfs get compression otus
    
    zfs get compression otus
    NAME  PROPERTY     VALUE     SOURCE
    otus  compression  zle       local

  Тип контрольной суммы: zfs get checksum otus

    zfs get checksum otus
    NAME  PROPERTY  VALUE      SOURCE
    otus  checksum  sha256     local

### Работа со снапшотом, поиск сообщения от преподавател

  Скачаем файл, указанный в задании: 
    wget -O otus_task2.file --no-check-certificate 'https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download'
  
  Восстановим файловую систему из снапшота: 
    
    zfs receive otus/test@today < otus_task2.file
  
  Далее, ищем в каталоге /otus/test файл с именем “secret_message”:
    
    find /otus/test -name "secret_message" /otus/test/task1/file_mess/secret_message
    
  Смотрим содержимое найденного файла:
    cat /otus/test/task1/file_mess/secret_message
    https://github.com/sindresorhus/awesome
    
  Тут мы видим ссылку на GitHub, можем скопировать её в адресную строку и посмотреть репозиторий.   
  
  Для конфигурации сервера (установки и настройки ZFS) необходимо
  написать отдельный Bash-скрипт и добавить его в Vagrantfile. Пример
  добавления скрипта в Vagrantfile:
   https://www.vagrantup.com/docs/provisioning/shell
