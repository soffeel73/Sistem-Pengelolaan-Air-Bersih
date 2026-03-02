<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import VueApexCharts from 'vue3-apexcharts'
import { 
  CurrencyDollarIcon, 
  BanknotesIcon,
  ArrowTrendingDownIcon,
  ArrowTrendingUpIcon,
  CheckBadgeIcon,
  PlusIcon,
  EyeIcon,
  PencilIcon,
  TrashIcon,
  XMarkIcon,
  DocumentArrowDownIcon,
  TableCellsIcon,
  CheckCircleIcon,
  XCircleIcon,
  ChevronDownIcon,
  CalendarDaysIcon,
  ExclamationTriangleIcon,
  ChartBarIcon
} from '@heroicons/vue/24/outline'

// ==================== STATE ====================
const isLoading = ref(false)
const summaryData = ref({
  pendapatan_air: 0,
  pemasukan_lainnya: 0,
  total_pendapatan: 0,
  total_piutang: 0,
  total_pengeluaran: 0,
  saldo_bersih: 0
})

// Active Submenu
const activeSubmenu = ref('tahunan') // 'tahunan' or 'bulanan'

// Yearly Report Data
const yearlyData = ref([])
const yearlyTotals = ref({})

// Daily Report Data
const dailyData = ref([])
const dailySummary = ref({ total_pemasukan: 0, total_pengeluaran: 0, saldo: 0 })

// Filters
const filterYear = ref(new Date().getFullYear())
const filterMonth = ref(new Date().getMonth() + 1)

// Pagination for daily data
const currentPageDaily = ref(1)
const itemsPerPage = ref(10)
const totalItemsDaily = ref(0)
const totalPagesDaily = ref(0)

// Modal States
const showTransactionModal = ref(false)
const showDetailModal = ref(false)
const showDeleteDialog = ref(false)
const transactionToDelete = ref(null)
const isEditMode = ref(false)
const transactionType = ref('pemasukan') // 'pemasukan' or 'pengeluaran'

// Detail Modal Data
const detailData = ref(null)
const detailLoading = ref(false)
const deletingTransaction = ref(false)

// Transaction Form
const transactionForm = ref({
  id: null,
  tipe: 'pemasukan',
  nama: '',
  kategori: '',
  nominal: '',
  tanggal: new Date().toISOString().split('T')[0],
  keterangan: ''
})
const transactionErrors = ref({})
const savingTransaction = ref(false)

// Toast
const toasts = ref([])
let toastId = 0

const goToPageDaily = (page) => {
  if (page >= 1 && page <= totalPagesDaily.value) {
    currentPageDaily.value = page
    fetchDailyData()
  }
}

// Kategori options
const kategoriPemasukan = ['Pasang Baru', 'Denda', 'Penjualan Material', 'Lainnya']
const kategoriPengeluaran = ['Operasional', 'Gaji', 'Maintenance', 'Lainnya']
const monthLabels = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
                     'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

// Computed kategori based on type
const currentKategoriOptions = computed(() => {
  return transactionForm.value.tipe === 'pemasukan' ? kategoriPemasukan : kategoriPengeluaran
})

// ==================== API ====================
const API_BASE = '/api/laporan_keuangan.php'

const fetchSummary = async () => {
  try {
    const response = await fetch(`${API_BASE}?action=summary&year=${filterYear.value}`)
    const data = await response.json()
    if (data.success) {
      summaryData.value = data.data
    }
  } catch (error) {
    console.error('Failed to fetch summary:', error)
  }
}

const fetchYearlyData = async () => {
  isLoading.value = true
  try {
    const response = await fetch(`${API_BASE}?action=yearly&year=${filterYear.value}`)
    const data = await response.json()
    if (data.success) {
      yearlyData.value = data.data
      yearlyTotals.value = data.totals
    }
  } catch (error) {
    console.error('Failed to fetch yearly data:', error)
  } finally {
    isLoading.value = false
  }
}

const fetchDailyData = async () => {
  isLoading.value = true
  try {
    const params = new URLSearchParams({
      action: 'daily',
      year: filterYear.value,
      month: filterMonth.value,
      page: currentPageDaily.value,
      limit: itemsPerPage.value
    })
    const response = await fetch(`${API_BASE}?${params.toString()}`)
    const data = await response.json()
    if (data.success) {
      dailyData.value = data.data
      dailySummary.value = data.summary
      if (data.pagination) {
        totalItemsDaily.value = data.pagination.total_items
        totalPagesDaily.value = data.pagination.total_pages
      }
    }
  } catch (error) {
    console.error('Failed to fetch daily data:', error)
  } finally {
    isLoading.value = false
  }
}

const fetchDetailData = async (month) => {
  detailLoading.value = true
  showDetailModal.value = true
  try {
    const response = await fetch(`${API_BASE}?action=detail&year=${filterYear.value}&month=${month}`)
    const data = await response.json()
    if (data.success) {
      detailData.value = data
    }
  } catch (error) {
    console.error('Failed to fetch detail:', error)
    showToast('Gagal mengambil detail laporan', 'error')
  } finally {
    detailLoading.value = false
  }
}

const saveTransaction = async () => {
  // Validation
  transactionErrors.value = {}
  if (!transactionForm.value.nama) transactionErrors.value.nama = 'Nama wajib diisi'
  if (!transactionForm.value.kategori) transactionErrors.value.kategori = 'Kategori wajib dipilih'
  if (!transactionForm.value.nominal || transactionForm.value.nominal <= 0) transactionErrors.value.nominal = 'Nominal harus lebih dari 0'
  if (!transactionForm.value.tanggal) transactionErrors.value.tanggal = 'Tanggal wajib diisi'
  
  if (Object.keys(transactionErrors.value).length > 0) return
  
  savingTransaction.value = true
  try {
    const method = isEditMode.value ? 'PUT' : 'POST'
    const url = isEditMode.value ? `${API_BASE}?id=${transactionForm.value.id}` : API_BASE
    
    const response = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        tipe: transactionForm.value.tipe,
        nama: transactionForm.value.nama,
        kategori: transactionForm.value.kategori,
        nominal: parseFloat(transactionForm.value.nominal),
        tanggal: transactionForm.value.tanggal,
        keterangan: transactionForm.value.keterangan
      })
    })
    
    const data = await response.json()
    
    if (data.success) {
      showToast(data.message, 'success')
      closeTransactionModal()
      refreshData()
    } else {
      if (data.errors) {
        transactionErrors.value = data.errors
      } else {
        showToast(data.message || 'Gagal menyimpan', 'error')
      }
    }
  } catch (error) {
    showToast('Gagal menyimpan transaksi', 'error')
  } finally {
    savingTransaction.value = false
  }
}

const openDeleteDialog = (transaction) => {
  transactionToDelete.value = transaction
  showDeleteDialog.value = true
}

const closeDeleteDialog = () => {
  showDeleteDialog.value = false
  transactionToDelete.value = null
}

const confirmDeleteTransaction = async () => {
  if (!transactionToDelete.value) return
  
  deletingTransaction.value = true
  try {
    const response = await fetch(`${API_BASE}?id=${transactionToDelete.value.id}`, { method: 'DELETE' })
    const data = await response.json()
    
    if (data.success) {
      showToast(data.message, 'success')
      refreshData()
      if (showDetailModal.value && detailData.value) {
        fetchDetailData(detailData.value.month)
      }
    } else {
      showToast(data.message || 'Gagal menghapus', 'error')
    }
  } catch (error) {
    showToast('Gagal menghapus transaksi', 'error')
  } finally {
    deletingTransaction.value = false
    closeDeleteDialog()
  }
}

const refreshData = () => {
  fetchSummary()
  if (activeSubmenu.value === 'tahunan') {
    fetchYearlyData()
  } else {
    fetchDailyData()
  }
}

// ==================== HELPERS ====================
const formatRupiah = (num) => {
  return 'Rp ' + parseFloat(num || 0).toLocaleString('id-ID')
}

const formatRupiahShort = (num) => {
  const value = parseFloat(num || 0)
  if (value >= 1000000000) {
    return 'Rp ' + (value / 1000000000).toFixed(1) + 'M'
  } else if (value >= 1000000) {
    return 'Rp ' + (value / 1000000).toFixed(1) + 'Jt'
  } else if (value >= 1000) {
    return 'Rp ' + (value / 1000).toFixed(0) + 'K'
  }
  return 'Rp ' + value.toLocaleString('id-ID')
}

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  const date = new Date(dateStr)
  return date.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

const showToast = (message, type = 'success') => {
  const id = ++toastId
  toasts.value.push({ id, message, type })
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }, 4000)
}

const openAddModal = (type) => {
  isEditMode.value = false
  transactionType.value = type
  transactionForm.value = {
    id: null,
    tipe: type,
    nama: '',
    kategori: type === 'pemasukan' ? kategoriPemasukan[0] : kategoriPengeluaran[0],
    nominal: '',
    tanggal: new Date().toISOString().split('T')[0],
    keterangan: ''
  }
  transactionErrors.value = {}
  showTransactionModal.value = true
}

const openEditModal = (transaction) => {
  isEditMode.value = true
  transactionType.value = transaction.tipe
  transactionForm.value = {
    id: transaction.id,
    tipe: transaction.tipe,
    nama: transaction.nama,
    kategori: transaction.kategori,
    nominal: transaction.nominal,
    tanggal: transaction.tanggal,
    keterangan: transaction.keterangan || ''
  }
  transactionErrors.value = {}
  showTransactionModal.value = true
}

const closeTransactionModal = () => {
  showTransactionModal.value = false
  transactionForm.value = { id: null, tipe: 'pemasukan', nama: '', kategori: '', nominal: '', tanggal: '', keterangan: '' }
  transactionErrors.value = {}
}

const closeDetailModal = () => {
  showDetailModal.value = false
  detailData.value = null
}

// ==================== CHART CONFIG ====================
const chartOptions = computed(() => ({
  chart: {
    type: 'bar',
    height: 250,
    toolbar: { show: false }
  },
  colors: ['#2EC4B6', '#FF9F1C'],
  plotOptions: {
    bar: {
      horizontal: false,
      columnWidth: '55%',
      borderRadius: 8
    }
  },
  dataLabels: { enabled: false },
  xaxis: {
    categories: ['Pemasukan', 'Pengeluaran']
  },
  yaxis: {
    labels: {
      formatter: (val) => formatRupiahShort(val)
    }
  },
  tooltip: {
    y: {
      formatter: (val) => formatRupiah(val)
    }
  }
}))

const chartSeries = computed(() => {
  if (!detailData.value) return [{ name: 'Jumlah', data: [0, 0] }]
  return [{
    name: 'Jumlah',
    data: detailData.value.chart_data?.values || [0, 0]
  }]
})

// ==================== EXPORT FUNCTIONS ====================
const exportPDF = async () => {
  const { jsPDF } = await import('jspdf')
  const autoTable = (await import('jspdf-autotable')).default
  
  const doc = new jsPDF('landscape')
  
  doc.setFontSize(18)
  doc.setTextColor(46, 196, 182)
  doc.text('LAPORAN KEUANGAN', 14, 22)
  doc.setFontSize(12)
  doc.setTextColor(100)
  doc.text(`Tahun ${filterYear.value}`, 14, 30)
  
  if (activeSubmenu.value === 'tahunan') {
    const tableData = yearlyData.value.map((row, idx) => [
      idx + 1,
      row.bulan,
      formatRupiah(row.pendapatan_air),
      formatRupiah(row.pemasukan_lainnya),
      formatRupiah(row.piutang),
      formatRupiah(row.pengeluaran),
      formatRupiah(row.saldo_bersih)
    ])
    
    // Add totals row
    tableData.push([
      '', 'TOTAL',
      formatRupiah(yearlyTotals.value.pendapatan_air),
      formatRupiah(yearlyTotals.value.pemasukan_lainnya),
      formatRupiah(yearlyTotals.value.piutang),
      formatRupiah(yearlyTotals.value.pengeluaran),
      formatRupiah(yearlyTotals.value.saldo_bersih)
    ])
    
    autoTable(doc, {
      startY: 40,
      head: [['No', 'Bulan', 'Pemasukan Air', 'Lainnya', 'Piutang', 'Pengeluaran', 'Saldo Bersih']],
      body: tableData,
      styles: { fontSize: 8 },
      headStyles: { fillColor: [46, 196, 182] },
      // Bold the last row (totals)
      didParseCell: (data) => {
        if (data.row.index === tableData.length - 1) {
          data.cell.styles.fontStyle = 'bold'
          data.cell.styles.fillColor = [240, 240, 240]
        }
      }
    })
  } else {
    doc.text(`Bulan: ${monthLabels[filterMonth.value]}`, 14, 38)
    
    // Fetch ALL data (no pagination) for PDF export
    try {
      const params = new URLSearchParams({
        action: 'daily',
        year: filterYear.value,
        month: filterMonth.value,
        page: 1,
        limit: 99999
      })
      const response = await fetch(`${API_BASE}?${params.toString()}`)
      const result = await response.json()
      
      if (!result.success) {
        showToast('Gagal mengambil data untuk PDF', 'error')
        return
      }
      
      const allData = result.data
      const summary = result.summary
      
      // Separate water payments from other transactions
      let waterCount = 0
      let waterTotal = 0
      const otherTransactions = []
      
      allData.forEach(row => {
        if (row.kategori === 'Tagihan Air Bulanan') {
          waterCount++
          waterTotal += parseFloat(row.nominal || 0)
        } else {
          otherTransactions.push(row)
        }
      })
      
      // Build combined rows
      const combinedRows = []
      const today = new Date().toISOString().split('T')[0] // tanggal cetak
      
      // Add single global water payment rows (Air + Admin) at today's date
      if (waterCount > 0) {
        const adminTotal = waterCount * 2000
        const airTotal = waterTotal - adminTotal
        
        combinedRows.push({
          tanggal: today,
          tipe: 'pemasukan',
          nama: `Pembayaran Air Pelanggan ${waterCount} pelanggan`,
          kategori: 'Tagihan Air',
          nominal: airTotal
        })
        combinedRows.push({
          tanggal: today,
          tipe: 'pemasukan',
          nama: `Pembayaran Admin ${waterCount} pelanggan`,
          kategori: 'Biaya Admin',
          nominal: adminTotal
        })
      }
      
      // Add other transactions
      otherTransactions.forEach(row => {
        combinedRows.push({
          tanggal: row.tanggal,
          tipe: row.tipe,
          nama: row.nama,
          kategori: row.kategori,
          nominal: parseFloat(row.nominal || 0)
        })
      })
      
      // Sort by date ascending
      combinedRows.sort((a, b) => new Date(a.tanggal) - new Date(b.tanggal))
      
      const tableData = combinedRows.map((row, idx) => [
        idx + 1,
        formatDate(row.tanggal),
        row.tipe === 'pemasukan' ? 'Pemasukan' : 'Pengeluaran',
        row.nama,
        row.kategori,
        formatRupiah(row.nominal)
      ])
      
      // Add summary rows
      tableData.push(
        ['', '', '', '', 'Total Pemasukan:', formatRupiah(summary.total_pemasukan)],
        ['', '', '', '', 'Total Pengeluaran:', formatRupiah(summary.total_pengeluaran)],
        ['', '', '', '', 'Saldo:', formatRupiah(summary.saldo)]
      )
      
      autoTable(doc, {
        startY: 48,
        head: [['No', 'Tanggal', 'Jenis', 'Nama', 'Kategori', 'Nominal']],
        body: tableData,
        styles: { fontSize: 8 },
        headStyles: { fillColor: [46, 196, 182] },
        // Style the summary rows
        didParseCell: (data) => {
          const totalRows = tableData.length
          if (data.row.index >= totalRows - 3) {
            data.cell.styles.fontStyle = 'bold'
            data.cell.styles.fillColor = [245, 245, 245]
          }
        }
      })
      
      showToast(`Berhasil export ${allData.length} data ke PDF`, 'success')
    } catch (error) {
      console.error('PDF export error:', error)
      showToast('Gagal export PDF', 'error')
      return
    }
  }
  
  doc.save(`Laporan-Keuangan-${filterYear.value}${activeSubmenu.value === 'bulanan' ? '-' + filterMonth.value : ''}.pdf`)
  if (activeSubmenu.value === 'tahunan') {
    showToast('PDF berhasil diunduh', 'success')
  }
}

const exportExcel = async () => {
  const XLSX = await import('xlsx')
  
  let wsData
  if (activeSubmenu.value === 'tahunan') {
    wsData = [
      ['LAPORAN KEUANGAN TAHUNAN - ' + filterYear.value],
      ['Sistem Basis Kas - Piutang tidak termasuk dalam Saldo Bersih'],
      [],
      ['No', 'Bulan', 'Pemasukan Air', 'Pemasukan Lainnya', 'Piutang', 'Pengeluaran', 'Saldo Bersih'],
      ...yearlyData.value.map((row, idx) => [
        idx + 1,
        row.bulan,
        row.pendapatan_air,
        row.pemasukan_lainnya,
        row.piutang,
        row.pengeluaran,
        row.saldo_bersih
      ]),
      [],
      ['TOTAL', '', yearlyTotals.value.pendapatan_air, yearlyTotals.value.pemasukan_lainnya, 
       yearlyTotals.value.piutang, yearlyTotals.value.pengeluaran, yearlyTotals.value.saldo_bersih]
    ]
  } else {
    wsData = [
      [`LAPORAN KEUANGAN BULANAN - ${monthLabels[filterMonth.value]} ${filterYear.value}`],
      [],
      ['No', 'Tanggal', 'Jenis', 'Nama', 'Kategori', 'Nominal'],
      ...dailyData.value.map((row, idx) => [
        idx + 1,
        row.tanggal,
        row.tipe === 'pemasukan' ? 'Pemasukan' : 'Pengeluaran',
        row.nama,
        row.kategori,
        row.nominal
      ]),
      [],
      ['', '', '', '', 'Total Pemasukan:', dailySummary.value.total_pemasukan],
      ['', '', '', '', 'Total Pengeluaran:', dailySummary.value.total_pengeluaran],
      ['', '', '', '', 'Saldo:', dailySummary.value.saldo]
    ]
  }
  
  const ws = XLSX.utils.aoa_to_sheet(wsData)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, activeSubmenu.value === 'tahunan' ? 'Tahunan' : 'Bulanan')
  
  XLSX.writeFile(wb, `Laporan-Keuangan-${filterYear.value}${activeSubmenu.value === 'bulanan' ? '-' + filterMonth.value : ''}.xlsx`)
  showToast('Excel berhasil diunduh', 'success')
}

// ==================== WATCHERS & LIFECYCLE ====================
watch(filterYear, () => {
  refreshData()
})

watch(filterMonth, () => {
  if (activeSubmenu.value === 'bulanan') {
    currentPageDaily.value = 1
    fetchDailyData()
  }
})

watch(activeSubmenu, (newVal) => {
  if (newVal === 'tahunan') {
    fetchYearlyData()
  } else {
    fetchDailyData()
  }
})

// Reset kategori when tipe changes
watch(() => transactionForm.value.tipe, (newTipe) => {
  if (newTipe === 'pemasukan') {
    transactionForm.value.kategori = kategoriPemasukan[0]
  } else {
    transactionForm.value.kategori = kategoriPengeluaran[0]
  }
})

onMounted(() => {
  fetchSummary()
  fetchYearlyData()
})
</script>

<template>
  <div class="space-y-6">
    <!-- Toast Notifications -->
    <Teleport to="body">
      <div class="fixed top-4 right-4 z-[100] space-y-2">
        <TransitionGroup name="toast">
          <div 
            v-for="toast in toasts" 
            :key="toast.id"
            :class="[
              'flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg text-white font-medium max-w-sm',
              toast.type === 'success' ? 'bg-green-500' : 'bg-red-500'
            ]"
          >
            <CheckCircleIcon v-if="toast.type === 'success'" class="w-5 h-5 flex-shrink-0" />
            <XCircleIcon v-else class="w-5 h-5 flex-shrink-0" />
            {{ toast.message }}
          </div>
        </TransitionGroup>
      </div>
    </Teleport>

    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div>
        <h2 class="text-2xl font-bold text-gray-900">Laporan Keuangan</h2>
        <p class="text-gray-500">Monitoring arus kas masuk dan keluar tahun {{ filterYear }}</p>
      </div>
    </div>

    <!-- Stat Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Total Pendapatan -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center">
            <CurrencyDollarIcon class="w-6 h-6 text-primary" />
          </div>
          <div>
            <p class="text-sm text-gray-500 font-medium">Total Pendapatan</p>
            <p class="text-xl font-bold text-primary">{{ formatRupiah(summaryData.total_pendapatan) }}</p>
          </div>
        </div>
      </div>
      
      <!-- Total Piutang -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 rounded-xl bg-amber-100 flex items-center justify-center">
            <BanknotesIcon class="w-6 h-6 text-accent" />
          </div>
          <div>
            <p class="text-sm text-gray-500 font-medium">Total Piutang</p>
            <p class="text-xl font-bold text-accent">{{ formatRupiah(summaryData.total_piutang) }}</p>
          </div>
        </div>
      </div>
      
      <!-- Total Pengeluaran -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 rounded-xl bg-red-100 flex items-center justify-center">
            <ArrowTrendingDownIcon class="w-6 h-6 text-red-500" />
          </div>
          <div>
            <p class="text-sm text-gray-500 font-medium">Total Pengeluaran</p>
            <p class="text-xl font-bold text-red-500">{{ formatRupiah(summaryData.total_pengeluaran) }}</p>
          </div>
        </div>
      </div>
      
      <!-- Saldo Bersih -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 rounded-xl bg-green-100 flex items-center justify-center">
            <CheckBadgeIcon class="w-6 h-6 text-green-600" />
          </div>
          <div>
            <p class="text-sm text-gray-500 font-medium">Saldo Bersih</p>
            <p class="text-xl font-bold" :class="summaryData.saldo_bersih >= 0 ? 'text-green-600' : 'text-red-500'">
              {{ formatRupiah(summaryData.saldo_bersih) }}
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Submenu Tabs -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-2">
      <div class="flex gap-2">
        <button 
          @click="activeSubmenu = 'tahunan'"
          :class="[
            'flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-xl font-bold transition-all',
            activeSubmenu === 'tahunan' 
              ? 'bg-primary text-white shadow-lg' 
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          ]"
        >
          <ChartBarIcon class="w-5 h-5" />
          Laporan Tahunan
        </button>
        <button 
          @click="activeSubmenu = 'bulanan'"
          :class="[
            'flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-xl font-bold transition-all',
            activeSubmenu === 'bulanan' 
              ? 'bg-primary text-white shadow-lg' 
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
          ]"
        >
          <CalendarDaysIcon class="w-5 h-5" />
          Laporan Bulanan
        </button>
      </div>
    </div>

    <!-- Filter & Actions Bar -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <!-- Filters -->
        <div class="flex flex-wrap items-center gap-3">
          <div class="flex items-center gap-2">
            <label class="text-sm font-medium text-gray-600">Tahun:</label>
            <div class="relative">
              <select 
                v-model="filterYear"
                class="appearance-none bg-white border border-gray-200 rounded-xl px-4 py-2.5 pr-10 font-bold text-gray-800 focus:outline-none focus:ring-2 focus:ring-primary/50"
              >
                <option v-for="y in [2026, 2027, 2028, 2029, 2030]" :key="y" :value="y">{{ y }}</option>
              </select>
              <ChevronDownIcon class="w-5 h-5 absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
            </div>
          </div>
          
          <!-- Month filter for Bulanan -->
          <div v-if="activeSubmenu === 'bulanan'" class="flex items-center gap-2">
            <label class="text-sm font-medium text-gray-600">Bulan:</label>
            <div class="relative">
              <select 
                v-model="filterMonth"
                class="appearance-none bg-white border border-gray-200 rounded-xl px-4 py-2.5 pr-10 font-bold text-gray-800 focus:outline-none focus:ring-2 focus:ring-primary/50"
              >
                <option v-for="m in 12" :key="m" :value="m">{{ monthLabels[m] }}</option>
              </select>
              <ChevronDownIcon class="w-5 h-5 absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
            </div>
          </div>
        </div>
        
        <!-- Actions -->
        <div class="flex flex-wrap items-center gap-2">
          <button 
            @click="openAddModal('pemasukan')"
            class="flex items-center gap-2 px-4 py-2.5 bg-primary text-white rounded-xl font-bold hover:bg-primary/90 transition-colors shadow-lg shadow-primary/25"
          >
            <ArrowTrendingUpIcon class="w-5 h-5" />
            <span class="hidden sm:inline">Pemasukan Lainnya</span>
          </button>
          
          <button 
            @click="openAddModal('pengeluaran')"
            class="flex items-center gap-2 px-4 py-2.5 bg-accent text-white rounded-xl font-bold hover:bg-accent/90 transition-colors"
          >
            <ArrowTrendingDownIcon class="w-5 h-5" />
            <span class="hidden sm:inline">Pengeluaran</span>
          </button>
          
          <button 
            @click="exportPDF"
            class="flex items-center gap-2 px-4 py-2.5 bg-red-500 text-white rounded-xl font-bold hover:bg-red-600 transition-colors"
          >
            <DocumentArrowDownIcon class="w-5 h-5" />
            <span class="hidden sm:inline">PDF</span>
          </button>
          
          <button 
            @click="exportExcel"
            class="flex items-center gap-2 px-4 py-2.5 bg-green-600 text-white rounded-xl font-bold hover:bg-green-700 transition-colors"
          >
            <TableCellsIcon class="w-5 h-5" />
            <span class="hidden sm:inline">Excel</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Yearly Report Table -->
    <div v-if="activeSubmenu === 'tahunan'" class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
      <div v-if="isLoading" class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
      
      <div v-else class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-primary text-white font-bold uppercase text-xs">
            <tr>
              <th class="px-3 py-4 text-center w-10">No</th>
              <th class="px-3 py-4 text-left">Bulan</th>
              <th class="px-3 py-4 text-right">Pemasukan Air</th>
              <th class="px-3 py-4 text-right">Lainnya</th>
              <th class="px-3 py-4 text-right">Piutang</th>
              <th class="px-3 py-4 text-right">Pengeluaran</th>
              <th class="px-3 py-4 text-right">Saldo Bersih</th>
              <th class="px-3 py-4 text-center w-14">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr 
              v-for="(row, index) in yearlyData" 
              :key="row.period_month" 
              class="hover:bg-frozen/20 transition-colors"
            >
              <td class="px-3 py-3 text-center font-medium text-gray-500 text-sm">{{ index + 1 }}</td>
              <td class="px-3 py-3 font-bold text-gray-900 text-sm">{{ row.bulan }}</td>
              <td class="px-3 py-3 text-right text-primary font-semibold text-sm">{{ formatRupiah(row.pendapatan_air) }}</td>
              <td class="px-3 py-3 text-right text-primary font-semibold text-sm">{{ formatRupiah(row.pemasukan_lainnya) }}</td>
              <td class="px-3 py-3 text-right font-semibold text-sm">
                <span :class="row.piutang > 0 ? 'text-amber-500' : 'text-gray-400'">
                  {{ formatRupiah(row.piutang) }}
                </span>
              </td>
              <td class="px-3 py-3 text-right font-semibold text-red-500 text-sm">{{ formatRupiah(row.pengeluaran) }}</td>
              <td class="px-3 py-3 text-right">
                <span class="font-bold text-sm" :class="row.saldo_bersih >= 0 ? 'text-green-600' : 'text-red-500'">
                  {{ formatRupiah(row.saldo_bersih) }}
                </span>
              </td>
              <td class="px-3 py-3">
                <div class="flex items-center justify-center">
                  <button 
                    @click="fetchDetailData(row.period_month)"
                    class="p-2 text-primary hover:bg-primary/10 rounded-full transition-colors"
                    title="Lihat Detail"
                  >
                    <EyeIcon class="w-5 h-5" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
          <tfoot class="bg-accent/10 font-bold">
            <tr>
              <td colspan="2" class="px-3 py-4 text-right text-gray-700 text-sm">TOTAL {{ filterYear }}</td>
              <td class="px-3 py-4 text-right text-primary text-sm">{{ formatRupiah(yearlyTotals.pendapatan_air) }}</td>
              <td class="px-3 py-4 text-right text-primary text-sm">{{ formatRupiah(yearlyTotals.pemasukan_lainnya) }}</td>
              <td class="px-3 py-4 text-right text-sm">
                <span :class="yearlyTotals.piutang > 0 ? 'text-amber-500' : 'text-gray-400'">
                  {{ formatRupiah(yearlyTotals.piutang) }}
                </span>
              </td>
              <td class="px-3 py-4 text-right text-red-500 text-sm">{{ formatRupiah(yearlyTotals.pengeluaran) }}</td>
              <td class="px-3 py-4 text-right text-sm">
                <span :class="yearlyTotals.saldo_bersih >= 0 ? 'text-green-600' : 'text-red-500'">
                  {{ formatRupiah(yearlyTotals.saldo_bersih) }}
                </span>
              </td>
              <td></td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>

    <!-- Daily Report Table -->
    <div v-if="activeSubmenu === 'bulanan'" class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
      <div v-if="isLoading" class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
      
      <div v-else-if="dailyData.length === 0" class="text-center py-12">
        <CalendarDaysIcon class="w-12 h-12 mx-auto text-gray-300 mb-4" />
        <p class="text-gray-500">Belum ada transaksi untuk {{ monthLabels[filterMonth] }} {{ filterYear }}</p>
      </div>
      
      <div v-else class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-primary text-white font-bold uppercase text-xs">
            <tr>
              <th class="px-4 py-4 text-center w-12">No</th>
              <th class="px-4 py-4 text-left">Tanggal</th>
              <th class="px-4 py-4 text-center">Jenis</th>
              <th class="px-4 py-4 text-left">Nama Transaksi</th>
              <th class="px-4 py-4 text-left">Kategori</th>
              <th class="px-4 py-4 text-right">Nominal</th>
              <th class="px-4 py-4 text-center">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr 
              v-for="(row, index) in dailyData" 
              :key="row.id || index" 
              class="hover:bg-frozen/20 transition-colors"
            >
              <td class="px-4 py-4 text-center font-medium text-gray-500">{{ (currentPageDaily - 1) * itemsPerPage + index + 1 }}</td>
              <td class="px-4 py-4 font-medium text-gray-700">{{ formatDate(row.tanggal) }}</td>
              <td class="px-4 py-4 text-center">
                <span 
                  :class="[
                    'px-2 py-1 rounded-full text-xs font-bold',
                    row.tipe === 'pemasukan' ? 'bg-primary/10 text-primary' : 'bg-amber-100 text-accent'
                  ]"
                >
                  {{ row.tipe === 'pemasukan' ? 'Pemasukan' : 'Pengeluaran' }}
                </span>
              </td>
              <td class="px-4 py-4">
                <div class="flex items-center gap-2">
                  <span class="font-medium text-gray-900">{{ row.nama }}</span>
                  <!-- Auto badge for automatic entries -->
                  <span 
                    v-if="row.kategori === 'Tagihan Air Bulanan' || row.kategori === 'Cicilan Tunggakan'"
                    class="inline-flex items-center gap-1 px-1.5 py-0.5 text-[10px] font-bold rounded bg-blue-100 text-blue-600"
                    title="Entri otomatis dari sistem"
                  >
                    ⚡ Otomatis
                  </span>
                </div>
              </td>
              <td class="px-4 py-4">
                <span 
                  :class="[
                    'px-2 py-0.5 rounded text-xs font-medium',
                    row.kategori === 'Tagihan Air Bulanan' ? 'bg-blue-50 text-blue-700' :
                    row.kategori === 'Cicilan Tunggakan' ? 'bg-purple-50 text-purple-700' :
                    'bg-gray-100 text-gray-600'
                  ]"
                >
                  {{ row.kategori }}
                </span>
              </td>
              <td class="px-4 py-4 text-right font-bold" :class="row.tipe === 'pemasukan' ? 'text-primary' : 'text-accent'">
                {{ row.tipe === 'pemasukan' ? '+' : '-' }}{{ formatRupiah(row.nominal) }}
              </td>
              <td class="px-4 py-4">
                <!-- Only show edit/delete for manual entries (not auto-recorded) -->
                <div v-if="row.id && !row.tagihan_id && row.kategori !== 'Tagihan Air Bulanan' && row.kategori !== 'Cicilan Tunggakan'" class="flex items-center justify-center gap-1">
                  <button 
                    @click="openEditModal(row)"
                    class="p-1.5 text-gray-400 hover:text-primary transition-colors"
                    title="Edit"
                  >
                    <PencilIcon class="w-4 h-4" />
                  </button>
                  <button 
                    @click="openDeleteDialog(row)"
                    class="p-1.5 text-gray-400 hover:text-red-500 transition-colors"
                    title="Hapus"
                  >
                    <TrashIcon class="w-4 h-4" />
                  </button>
                </div>
                <span v-else class="text-gray-300 text-sm">-</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      
      <!-- Pagination for Daily Data -->
      <div v-if="dailyData.length > 0" class="px-6 py-4 border-t border-gray-100 flex flex-col sm:flex-row items-center justify-between gap-4">
        <div class="text-sm text-gray-500">
          Menampilkan {{ dailyData.length }} dari {{ totalItemsDaily }} transaksi
        </div>
        <div v-if="totalPagesDaily > 1" class="flex items-center gap-2">
          <button @click="goToPageDaily(1)" :disabled="currentPageDaily === 1" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">&laquo;</button>
          <button @click="goToPageDaily(currentPageDaily - 1)" :disabled="currentPageDaily === 1" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">&lsaquo;</button>
          <template v-for="page in totalPagesDaily" :key="page">
            <button 
              v-if="page === 1 || page === totalPagesDaily || (page >= currentPageDaily - 1 && page <= currentPageDaily + 1)"
              @click="goToPageDaily(page)"
              class="px-3 py-1.5 text-sm rounded-lg border transition-colors"
              :class="page === currentPageDaily ? 'bg-primary text-white border-primary' : 'border-gray-200 hover:bg-gray-50'"
            >{{ page }}</button>
            <span v-else-if="page === currentPageDaily - 2 || page === currentPageDaily + 2" class="text-gray-400">...</span>
          </template>
          <button @click="goToPageDaily(currentPageDaily + 1)" :disabled="currentPageDaily === totalPagesDaily" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">&rsaquo;</button>
          <button @click="goToPageDaily(totalPagesDaily)" :disabled="currentPageDaily === totalPagesDaily" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">&raquo;</button>
        </div>
      </div>
      
      <!-- Daily Summary Footer -->
      <div v-if="dailyData.length > 0" class="px-6 py-4 bg-frozen/50 border-t border-gray-100">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div class="flex flex-wrap items-center gap-6">
            <div class="flex items-center gap-2">
              <span class="text-gray-600 text-sm">Pemasukan:</span>
              <span class="font-bold text-primary">{{ formatRupiah(dailySummary.total_pemasukan) }}</span>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-gray-600 text-sm">Pengeluaran:</span>
              <span class="font-bold text-red-500">{{ formatRupiah(dailySummary.total_pengeluaran) }}</span>
            </div>
            <div class="flex items-center gap-2" title="Piutang tidak termasuk dalam Saldo (Basis Kas)">
              <span class="text-gray-600 text-sm">Piutang:</span>
              <span class="font-bold" :class="dailySummary.piutang > 0 ? 'text-amber-500' : 'text-gray-400'">
                {{ formatRupiah(dailySummary.piutang || 0) }}
              </span>
            </div>
          </div>
          <div class="flex items-center gap-2 bg-white px-4 py-2 rounded-xl shadow-sm">
            <span class="text-gray-700 font-bold text-sm">Saldo Bersih:</span>
            <span class="font-bold text-lg" :class="dailySummary.saldo >= 0 ? 'text-green-600' : 'text-red-500'">
              {{ formatRupiah(dailySummary.saldo) }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Add/Edit Transaction Modal -->
    <Teleport to="body">
      <div v-if="showTransactionModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" @click="closeTransactionModal"></div>
        
        <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-md transform transition-all">
          <div 
            :class="[
              'px-6 py-4 flex items-center justify-between rounded-t-2xl text-white',
              transactionForm.tipe === 'pemasukan' ? 'bg-primary' : 'bg-accent'
            ]"
          >
            <h3 class="text-lg font-bold">
              {{ isEditMode ? 'Edit' : 'Tambah' }} {{ transactionForm.tipe === 'pemasukan' ? 'Pemasukan Lainnya' : 'Pengeluaran' }}
            </h3>
            <button @click="closeTransactionModal" class="p-1 hover:bg-white/20 rounded-full transition-colors">
              <XMarkIcon class="w-6 h-6" />
            </button>
          </div>
          
          <form @submit.prevent="saveTransaction" class="p-6 space-y-4">
            <!-- Nama -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Nama {{ transactionForm.tipe === 'pemasukan' ? 'Pemasukan' : 'Pengeluaran' }}</label>
              <input 
                v-model="transactionForm.nama"
                type="text"
                :placeholder="transactionForm.tipe === 'pemasukan' ? 'Misal: Pasang Baru, Denda' : 'Misal: Listrik, Gaji'"
                class="w-full px-4 py-3 border rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/50"
                :class="transactionErrors.nama ? 'border-red-500' : 'border-gray-200'"
              >
              <p v-if="transactionErrors.nama" class="text-red-500 text-sm mt-1">{{ transactionErrors.nama }}</p>
            </div>
            
            <!-- Kategori -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Kategori</label>
              <select 
                v-model="transactionForm.kategori"
                class="w-full px-4 py-3 border rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/50"
                :class="transactionErrors.kategori ? 'border-red-500' : 'border-gray-200'"
              >
                <option v-for="kat in currentKategoriOptions" :key="kat" :value="kat">{{ kat }}</option>
              </select>
              <p v-if="transactionErrors.kategori" class="text-red-500 text-sm mt-1">{{ transactionErrors.kategori }}</p>
            </div>
            
            <!-- Nominal -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Nominal (Rp)</label>
              <input 
                v-model.number="transactionForm.nominal"
                type="number"
                min="0"
                placeholder="0"
                class="w-full px-4 py-3 border rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/50"
                :class="transactionErrors.nominal ? 'border-red-500' : 'border-gray-200'"
              >
              <p v-if="transactionErrors.nominal" class="text-red-500 text-sm mt-1">{{ transactionErrors.nominal }}</p>
            </div>
            
            <!-- Tanggal -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Tanggal</label>
              <input 
                v-model="transactionForm.tanggal"
                type="date"
                class="w-full px-4 py-3 border rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/50"
                :class="transactionErrors.tanggal ? 'border-red-500' : 'border-gray-200'"
              >
              <p v-if="transactionErrors.tanggal" class="text-red-500 text-sm mt-1">{{ transactionErrors.tanggal }}</p>
            </div>
            
            <!-- Keterangan -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Keterangan (Opsional)</label>
              <textarea 
                v-model="transactionForm.keterangan"
                rows="2"
                placeholder="Keterangan tambahan..."
                class="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/50 resize-none"
              ></textarea>
            </div>
            
            <!-- Actions -->
            <div class="flex gap-3 pt-2">
              <button 
                type="button"
                @click="closeTransactionModal"
                class="flex-1 px-4 py-3 bg-gray-100 text-gray-700 rounded-xl font-bold hover:bg-gray-200 transition-colors"
              >
                Batal
              </button>
              <button 
                type="submit"
                :disabled="savingTransaction"
                :class="[
                  'flex-1 px-4 py-3 rounded-xl font-bold transition-colors disabled:opacity-50 text-white',
                  transactionForm.tipe === 'pemasukan' ? 'bg-primary hover:bg-primary/90' : 'bg-accent hover:bg-accent/90'
                ]"
              >
                {{ savingTransaction ? 'Menyimpan...' : (isEditMode ? 'Simpan Perubahan' : 'Tambah') }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Teleport>

    <!-- Detail Modal -->
    <Teleport to="body">
      <div v-if="showDetailModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" @click="closeDetailModal"></div>
        
        <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] overflow-hidden transform transition-all">
          <div class="bg-primary text-white px-6 py-4 flex items-center justify-between">
            <h3 class="text-lg font-bold">Detail Laporan {{ detailData?.periode || '' }}</h3>
            <button @click="closeDetailModal" class="p-1 hover:bg-white/20 rounded-full transition-colors">
              <XMarkIcon class="w-6 h-6" />
            </button>
          </div>
          
          <div class="p-6 overflow-y-auto max-h-[calc(90vh-180px)]">
            <div v-if="detailLoading" class="flex items-center justify-center py-8">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
            
            <template v-else-if="detailData">
              <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <!-- Breakdown Air -->
                <div class="bg-frozen/50 rounded-xl p-4">
                  <h4 class="font-bold text-gray-900 mb-3 flex items-center gap-2">
                    <CurrencyDollarIcon class="w-5 h-5 text-primary" />
                    Pendapatan Air
                  </h4>
                  <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                      <span class="text-gray-600">Blok 1 (0-5 m³)</span>
                      <span class="font-bold text-primary">{{ formatRupiah(detailData.breakdown_air.blok_1) }}</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Blok 2 (>5-10 m³)</span>
                      <span class="font-bold text-primary">{{ formatRupiah(detailData.breakdown_air.blok_2) }}</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Blok 3 (>10 m³)</span>
                      <span class="font-bold text-primary">{{ formatRupiah(detailData.breakdown_air.blok_3) }}</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Biaya Admin ({{ detailData.breakdown_air.customer_count }} pelanggan)</span>
                      <span class="font-bold text-primary">{{ formatRupiah(detailData.breakdown_air.admin_fee) }}</span>
                    </div>
                    <div v-if="detailData.breakdown_air.pembayaran_tunggakan > 0" class="flex justify-between">
                      <span class="text-gray-600">Pembayaran Tunggakan/Lain</span>
                      <span class="font-bold text-primary">{{ formatRupiah(detailData.breakdown_air.pembayaran_tunggakan) }}</span>
                    </div>
                    <div class="flex justify-between pt-2 border-t border-primary/20">
                      <span class="font-bold text-gray-900">Subtotal Air</span>
                      <span class="font-bold text-primary">{{ formatRupiah(detailData.breakdown_air.total) }}</span>
                    </div>
                  </div>
                </div>
                
                <!-- Pemasukan Lainnya & Pengeluaran -->
                <div class="space-y-4">
                  <!-- Pemasukan Lainnya -->
                  <div class="bg-green-50 rounded-xl p-4">
                    <h4 class="font-bold text-gray-900 mb-3 flex items-center gap-2">
                      <ArrowTrendingUpIcon class="w-5 h-5 text-green-600" />
                      Pemasukan Lainnya
                    </h4>
                    <div v-if="detailData.pemasukan_lainnya.length === 0" class="text-gray-500 text-sm py-2 text-center">
                      Tidak ada pemasukan lainnya
                    </div>
                    <div v-else class="space-y-2 text-sm">
                      <div v-for="item in detailData.pemasukan_lainnya" :key="item.id" class="flex justify-between">
                        <span class="text-gray-600">{{ item.nama }}</span>
                        <span class="font-bold text-green-600">{{ formatRupiah(item.nominal) }}</span>
                      </div>
                      <div class="flex justify-between pt-2 border-t border-green-200">
                        <span class="font-bold">Subtotal</span>
                        <span class="font-bold text-green-600">{{ formatRupiah(detailData.total_pemasukan_lainnya) }}</span>
                      </div>
                    </div>
                  </div>
                  
                  <!-- Pengeluaran -->
                  <div class="bg-amber-50 rounded-xl p-4">
                    <h4 class="font-bold text-gray-900 mb-3 flex items-center gap-2">
                      <ArrowTrendingDownIcon class="w-5 h-5 text-accent" />
                      Pengeluaran
                    </h4>
                    <div v-if="detailData.pengeluaran.length === 0" class="text-gray-500 text-sm py-2 text-center">
                      Tidak ada pengeluaran
                    </div>
                    <div v-else class="space-y-2 text-sm">
                      <div v-for="item in detailData.pengeluaran" :key="item.id" class="flex justify-between">
                        <span class="text-gray-600">{{ item.nama }}</span>
                        <span class="font-bold text-accent">{{ formatRupiah(item.nominal) }}</span>
                      </div>
                      <div class="flex justify-between pt-2 border-t border-accent/20">
                        <span class="font-bold">Subtotal</span>
                        <span class="font-bold text-accent">{{ formatRupiah(detailData.total_pengeluaran) }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              
              <!-- Chart -->
              <div class="mt-6 bg-gray-50 rounded-xl p-4">
                <h4 class="font-bold text-gray-900 mb-3">Perbandingan Pemasukan vs Pengeluaran</h4>
                <VueApexCharts
                  type="bar"
                  height="250"
                  :options="chartOptions"
                  :series="chartSeries"
                />
              </div>
            </template>
          </div>
          
          <div v-if="detailData && !detailLoading" class="px-6 py-4 bg-primary text-white">
            <div class="flex items-center justify-between">
              <span class="font-bold text-lg">Laba/Rugi Bulan Ini:</span>
              <span class="text-2xl font-bold">{{ formatRupiah(detailData.laba_rugi) }}</span>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Delete Confirmation Dialog -->
    <Teleport to="body">
      <div v-if="showDeleteDialog" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" @click="closeDeleteDialog"></div>
        
        <!-- Dialog Content -->
        <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 text-center">
          <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-red-100 flex items-center justify-center">
            <ExclamationTriangleIcon class="w-8 h-8 text-red-500" />
          </div>
          
          <h3 class="text-xl font-bold text-gray-900 mb-2">Konfirmasi Hapus</h3>
          <p class="text-gray-500 mb-4">
            Apakah Anda yakin ingin menghapus transaksi ini?
          </p>
          
          <div v-if="transactionToDelete" class="bg-frozen/50 rounded-xl p-4 mb-6 text-left">
            <div class="space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-gray-500">Nama:</span>
                <span class="font-bold text-gray-900">{{ transactionToDelete.nama }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-500">Kategori:</span>
                <span class="font-bold text-gray-900">{{ transactionToDelete.kategori }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-500">Nominal:</span>
                <span class="font-bold" :class="transactionToDelete.tipe === 'pemasukan' ? 'text-primary' : 'text-red-500'">
                  {{ formatRupiah(transactionToDelete.nominal) }}
                </span>
              </div>
            </div>
          </div>
          
          <div class="flex items-center justify-center gap-3">
            <button 
              @click="closeDeleteDialog"
              :disabled="deletingTransaction"
              class="px-6 py-2.5 rounded-xl text-gray-600 font-bold hover:bg-gray-100 transition-colors border border-gray-200 disabled:opacity-50"
            >
              Batal
            </button>
            <button 
              @click="confirmDeleteTransaction"
              :disabled="deletingTransaction"
              class="px-6 py-2.5 rounded-xl bg-red-500 text-white font-bold shadow-lg shadow-red-500/30 hover:bg-red-600 transition-all disabled:opacity-50"
            >
              {{ deletingTransaction ? 'Menghapus...' : 'Ya, Hapus' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.toast-enter-active,
.toast-leave-active {
  transition: all 0.3s ease;
}
.toast-enter-from {
  opacity: 0;
  transform: translateX(100%);
}
.toast-leave-to {
  opacity: 0;
  transform: translateX(100%);
}
</style>
