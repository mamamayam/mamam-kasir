import '../domain/pelanggan_models.dart';

/// STATIC DUMMY DATA for the Pelanggan placeholder — copied 1:1 from the
/// approved `pelanggan_v3_gabungan.html` mockup so the screens can be
/// reviewed against it. Not read from / written to the database, not
/// synced. Replaced by the real repository in a later phase.
const List<Pelanggan> pelangganDummyData = [
  Pelanggan(
    id: 1,
    name: 'Budi Santoso',
    phones: ['0812 3456 7890'],
    address: '',
    lastPurchase: PelangganLastPurchase(
      text: '2x Ayam Geprek, 1x Es Teh',
      time: 'Kemarin',
      date: '5 Sep 2026, 18:20',
      total: 68000,
    ),
    omzet: 4850000,
    trxCount: 32,
    lastOrderDaysAgo: 1,
    history: [
      PelangganRiwayat(
        date: '5 Sep 2026, 18:20',
        total: 68000,
        items: '2x Ayam Geprek, 1x Es Teh',
        tags: ['Dine In', 'QRIS'],
      ),
      PelangganRiwayat(
        date: '1 Sep 2026, 12:10',
        total: 92000,
        items: '1x Paket Hemat B, 1x Jus Mangga',
        tags: ['Take Away', 'Cash'],
      ),
    ],
  ),
  Pelanggan(
    id: 2,
    name: 'Siti Aminah',
    phones: ['0856 1122 3344'],
    address: 'Jl. Kenanga No. 8',
    lastPurchase: PelangganLastPurchase(
      text: '1x Paket Hemat A, 1x Jus Alpukat',
      time: '3 hari lalu',
      date: '2 Sep 2026, 09:40',
      total: 45000,
    ),
    omzet: 3210000,
    trxCount: 27,
    lastOrderDaysAgo: 3,
    history: [
      PelangganRiwayat(
        date: '2 Sep 2026, 09:40',
        total: 45000,
        items: '1x Paket Hemat A, 1x Jus Alpukat',
        tags: ['Dine In', 'Cash'],
      ),
    ],
  ),
  Pelanggan(
    id: 3,
    name: 'Andi Wijaya',
    phones: ['0821 9988 7766'],
    address: '',
    lastPurchase: PelangganLastPurchase(
      text: '3x Nasi Goreng Spesial',
      time: '5 hari lalu',
      date: '31 Agu 2026, 20:05',
      total: 105000,
    ),
    omzet: 2640000,
    trxCount: 21,
    lastOrderDaysAgo: 5,
    history: [
      PelangganRiwayat(
        date: '31 Agu 2026, 20:05',
        total: 105000,
        items: '3x Nasi Goreng Spesial',
        tags: ['Take Away', 'QRIS'],
      ),
    ],
  ),
  Pelanggan(
    id: 4,
    name: 'Dewi Lestari',
    phones: ['0813 5566 7788'],
    address: 'Jl. Merpati No. 12, RT 04/RW 02, Kel. Sukamaju',
    lastPurchase: PelangganLastPurchase(
      text: '1x Es Kopi Susu, 2x Roti Bakar',
      time: '1 minggu lalu',
      date: '5 Sep 2026, 14:32',
      total: 68000,
    ),
    omzet: 1920000,
    trxCount: 14,
    lastOrderDaysAgo: 7,
    history: [
      PelangganRiwayat(
        date: '5 Sep 2026, 14:32',
        total: 68000,
        items: '1x Es Kopi Susu, 2x Roti Bakar Coklat',
        tags: ['Dine In', 'QRIS'],
      ),
      PelangganRiwayat(
        date: '29 Agu 2026, 11:05',
        total: 145000,
        items: '2x Ayam Geprek Sambal Bawang, 2x Es Teh Manis',
        tags: ['Take Away', 'Cash'],
      ),
      PelangganRiwayat(
        date: '18 Agu 2026, 19:47',
        total: 92000,
        items: '1x Paket Hemat B, 1x Jus Mangga',
        tags: ['Dine In', 'Cash'],
      ),
    ],
  ),
  Pelanggan(
    id: 5,
    name: 'Rahmat Hidayat',
    phones: [],
    address: '',
    lastPurchase: null,
    omzet: 0,
    trxCount: 0,
    lastOrderDaysAgo: null,
    history: [],
  ),
  Pelanggan(
    id: 6,
    name: 'Joko Prasetyo',
    phones: ['0857 4433 2211'],
    address: '',
    lastPurchase: PelangganLastPurchase(
      text: '1x Nasi Goreng Spesial',
      time: '2 bulan lalu',
      date: '10 Jul 2026, 13:00',
      total: 35000,
    ),
    omzet: 385000,
    trxCount: 6,
    lastOrderDaysAgo: 67,
    history: [
      PelangganRiwayat(
        date: '10 Jul 2026, 13:00',
        total: 35000,
        items: '1x Nasi Goreng Spesial',
        tags: ['Take Away', 'Cash'],
      ),
    ],
  ),
  Pelanggan(
    id: 7,
    name: 'Maya Sari',
    phones: ['0878 6655 4433'],
    address: '',
    lastPurchase: PelangganLastPurchase(
      text: '1x Es Teh, 1x Ayam Geprek',
      time: '45 hari lalu',
      date: '1 Agu 2026, 10:15',
      total: 38000,
    ),
    omzet: 760000,
    trxCount: 9,
    lastOrderDaysAgo: 45,
    history: [
      PelangganRiwayat(
        date: '1 Agu 2026, 10:15',
        total: 38000,
        items: '1x Es Teh, 1x Ayam Geprek',
        tags: ['Dine In', 'Cash'],
      ),
    ],
  ),
];
