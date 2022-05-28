# SDHCI_driver_for_Kolibrios

Driver for SD host controller on Kolibri OS

Version controller:
- 1.0 - no supported
- 2.0 - no supported 
- 3.0 - no supported
- 4.0 - no supported

Version OS: 
* rev 9764

Bus protocol:
- SD Bus protocol - no supported
- SPI Bus protocol - no supported
- UHS-II Bus protocol - no supported
- PCIe/NVMe Bus protocol - no supported

TODO:
- инициализация контроллера, вывод информации об контроллере
- Установка изначальных значений для работы контроллера
- ~~регистрация обработчика прерываний~~
- документирование и реализация команд контроллера
- написание алгоритма инициализации SD карт
- написание функций передачи блоков через SDMA и ADMA и без применения DMA
- реализация функций card_init и card_destryct
- написание алгоритма инициализации для карт с интерфейсом SPI
- Вывод базовых данных о карте
- реализация функций обработки сообщений контроллера
- реализация функций SDIO и их экспорт для драйверов и прикладного ПО
- реализация встроенного драйвера на SD карты памяти
