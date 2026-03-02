<script setup>
import { ref, computed, watch } from 'vue'
import { 
  PrinterIcon, 
  MagnifyingGlassIcon, 
  XMarkIcon,
  DocumentTextIcon,
  PlusIcon,
  TrashIcon
} from '@heroicons/vue/24/outline'

// ==================== STATE ====================
const isLoading = ref(false)
const searchQuery = ref('')
const searchResults = ref([])
const showModal = ref(false)

// Multi-struk: store up to 6 receipts
const strukList = ref([])
const MAX_STRUK = 6

// Toast
const toasts = ref([])
let toastId = 0

const API_BASE = '/api/cetak_struk.php'

// Month names
const monthNames = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
                    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

// Current selection state
const currentPelanggan = ref(null)
const currentPeriods = ref([])
const currentSelectedPeriod = ref(null)

// ==================== COMPUTED ====================
const getMonthName = (month) => monthNames[parseInt(month)] || month
const canAddMore = computed(() => strukList.value.length < MAX_STRUK)

// ==================== FUNCTIONS ====================
const showToast = (message, type = 'success') => {
  const id = ++toastId
  toasts.value.push({ id, message, type })
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }, 3000)
}

const openModal = () => {
  showModal.value = true
  resetCurrentSelection()
}

const closeModal = () => {
  showModal.value = false
}

const resetCurrentSelection = () => {
  searchQuery.value = ''
  searchResults.value = []
  currentPelanggan.value = null
  currentPeriods.value = []
  currentSelectedPeriod.value = null
}

const resetAll = () => {
  strukList.value = []
  resetCurrentSelection()
}

// Search pelanggan
const searchPelanggan = async () => {
  if (searchQuery.value.length < 2) {
    searchResults.value = []
    return
  }
  
  isLoading.value = true
  try {
    const response = await fetch(`${API_BASE}?action=search&q=${encodeURIComponent(searchQuery.value)}`)
    const data = await response.json()
    if (data.success) {
      searchResults.value = data.data
    }
  } catch (error) {
    console.error('Search error:', error)
  } finally {
    isLoading.value = false
  }
}

// Select pelanggan and load periods
const selectPelanggan = async (pelanggan) => {
  currentPelanggan.value = pelanggan
  searchResults.value = []
  searchQuery.value = `${pelanggan.customer_id} - ${pelanggan.name}`
  
  isLoading.value = true
  try {
    const response = await fetch(`${API_BASE}?action=periods&pelanggan_id=${pelanggan.id}`)
    const data = await response.json()
    if (data.success) {
      currentPeriods.value = data.data
    }
  } catch (error) {
    console.error('Load periods error:', error)
  } finally {
    isLoading.value = false
  }
}

// Add struk to list
const addStrukToList = async () => {
  if (!currentSelectedPeriod.value || !canAddMore.value) return
  
  isLoading.value = true
  try {
    const response = await fetch(`${API_BASE}?action=detail&id=${currentSelectedPeriod.value}`)
    const data = await response.json()
    if (data.success) {
      strukList.value.push(data.data)
      showToast(`Struk ${currentPelanggan.value.name} ditambahkan (${strukList.value.length}/6)`)
      resetCurrentSelection()
    } else {
      showToast(data.message || 'Gagal memuat data struk', 'error')
    }
  } catch (error) {
    console.error('Load detail error:', error)
    showToast('Gagal memuat data struk', 'error')
  } finally {
    isLoading.value = false
  }
}

// Remove struk from list
const removeStruk = (index) => {
  strukList.value.splice(index, 1)
}

// Format rupiah
const formatRupiah = (value) => {
  return parseFloat(value || 0).toLocaleString('id-ID')
}

// Print struk
const printStruk = () => {
  if (strukList.value.length === 0) {
    showToast('Tambahkan minimal 1 struk untuk dicetak', 'error')
    return
  }
  window.print()
}

// Debounce search
let searchTimeout = null
watch(searchQuery, (newVal) => {
  if (searchTimeout) clearTimeout(searchTimeout)
  if (newVal && !currentPelanggan.value) {
    searchTimeout = setTimeout(() => {
      searchPelanggan()
    }, 300)
  }
})

// Calculate Total Biaya (Pemakaian + Admin)
const getTotalBiaya = (struk) => {
  const p1 = Number(struk.tarif_breakdown?.pemakaian1?.subtotal || 0)
  const p2 = Number(struk.tarif_breakdown?.pemakaian2?.subtotal || 0)
  const p3 = Number(struk.tarif_breakdown?.pemakaian3?.subtotal || 0)
  const admin = Number(struk.biaya_admin || 2000)
  return p1 + p2 + p3 + admin
}
</script>

<template>
  <div class="min-h-screen">
    <!-- Page Header -->
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">Cetak Struk Tagihan</h1>
      <p class="text-gray-500">Cetak 6 struk tagihan dalam 1 kertas F4 - HIPPAMS TIRTO JOYO</p>
    </div>

    <!-- Main Card -->
    <div class="bg-white rounded-2xl shadow-xl border border-gray-100 p-8">
      <div class="text-center py-12">
        <div class="w-24 h-24 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-full flex items-center justify-center mx-auto mb-6 shadow-xl shadow-blue-500/30">
          <PrinterIcon class="w-12 h-12 text-white" />
        </div>
        <h2 class="text-2xl font-bold text-gray-900 mb-4">Cetak Multi-Struk (6 per Kertas)</h2>
        <p class="text-gray-500 mb-8 max-w-md mx-auto">
          Pilih hingga 6 pelanggan untuk dicetak dalam 1 lembar kertas F4
        </p>
        <button 
          @click="openModal"
          class="px-8 py-4 bg-gradient-to-r from-blue-500 to-indigo-600 text-white font-bold rounded-xl shadow-lg shadow-blue-500/30 hover:shadow-xl hover:shadow-blue-500/40 transition-all transform hover:-translate-y-1"
        >
          <span class="flex items-center gap-3">
            <DocumentTextIcon class="w-6 h-6" />
            Buat Struk Baru
          </span>
        </button>
      </div>
    </div>

    <!-- Toast Notifications -->
    <TransitionGroup name="toast" tag="div" class="fixed top-4 right-4 z-50 space-y-2 no-print">
      <div 
        v-for="toast in toasts" 
        :key="toast.id"
        :class="[
          'px-6 py-3 rounded-xl shadow-xl text-white font-medium',
          toast.type === 'success' ? 'bg-green-500' : 'bg-red-500'
        ]"
      >
        {{ toast.message }}
      </div>
    </TransitionGroup>

    <!-- Modal -->
    <Teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-start justify-center p-4 pt-10 overflow-y-auto no-print">
        <!-- Backdrop -->
        <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" @click="closeModal"></div>
        
        <!-- Modal Content -->
        <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-6xl mb-8">
          <!-- Header -->
          <div class="bg-gradient-to-r from-blue-600 to-indigo-600 text-white px-6 py-4 rounded-t-2xl flex items-center justify-between">
            <div class="flex items-center gap-3">
              <PrinterIcon class="w-6 h-6" />
              <h3 class="text-lg font-bold">Buat Multi-Struk ({{ strukList.length }}/6)</h3>
            </div>
            <button @click="closeModal" class="p-1 hover:bg-white/20 rounded-full transition-colors">
              <XMarkIcon class="w-6 h-6" />
            </button>
          </div>
          
          <!-- Body -->
          <div class="p-6">
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <!-- Left: Add Struk Form -->
              <div class="border border-gray-200 rounded-xl p-4">
                <h4 class="font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <PlusIcon class="w-5 h-5" />
                  Tambah Struk
                </h4>
                
                <!-- Search -->
                <div class="mb-4">
                  <label class="block text-sm font-medium text-gray-700 mb-2">Cari Pelanggan</label>
                  <div class="relative">
                    <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                    <input 
                      v-model="searchQuery"
                      @focus="currentPelanggan = null; currentPeriods = []"
                      type="text"
                      class="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                      placeholder="Ketik nama atau No. HPM..."
                      :disabled="!canAddMore"
                    >
                    
                    <!-- Search Results -->
                    <div 
                      v-if="searchResults.length > 0 && !currentPelanggan"
                      class="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-xl z-10 max-h-48 overflow-y-auto"
                    >
                      <button
                        v-for="result in searchResults"
                        :key="result.id"
                        @click="selectPelanggan(result)"
                        class="w-full px-3 py-2 text-left hover:bg-blue-50 text-sm border-b border-gray-100 last:border-0"
                      >
                        <div class="font-bold">{{ result.customer_id }} - {{ result.name }}</div>
                        <div class="text-xs text-gray-500">{{ result.address }}</div>
                      </button>
                    </div>
                  </div>
                </div>
                
                <!-- Period Select -->
                <div class="mb-4" v-if="currentPelanggan && currentPeriods.length > 0">
                  <label class="block text-sm font-medium text-gray-700 mb-2">Pilih Periode</label>
                  <select 
                    v-model="currentSelectedPeriod"
                    class="w-full px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                  >
                    <option :value="null">-- Pilih --</option>
                    <option v-for="p in currentPeriods" :key="p.id" :value="p.id">
                      {{ getMonthName(p.period_month) }} {{ p.period_year }} ({{ p.jumlah_pakai }} M³)
                    </option>
                  </select>
                </div>
                
                <!-- Add Button -->
                <button 
                  @click="addStrukToList"
                  :disabled="!currentSelectedPeriod || !canAddMore || isLoading"
                  class="w-full py-2 bg-green-500 text-white font-bold rounded-lg hover:bg-green-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                >
                  <PlusIcon class="w-5 h-5" />
                  Tambahkan ke Daftar
                </button>
                
                <div v-if="!canAddMore" class="mt-2 text-center text-sm text-amber-600 font-medium">
                  Maksimal 6 struk sudah tercapai
                </div>
              </div>
              
              <!-- Right: Struk List -->
              <div class="border border-gray-200 rounded-xl p-4">
                <h4 class="font-bold text-gray-900 mb-4">Daftar Struk ({{ strukList.length }}/6)</h4>
                
                <div v-if="strukList.length === 0" class="text-center py-8 text-gray-400">
                  Belum ada struk ditambahkan
                </div>
                
                <div v-else class="space-y-2 max-h-64 overflow-y-auto">
                  <div 
                    v-for="(struk, index) in strukList" 
                    :key="index"
                    class="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                  >
                    <div>
                      <div class="font-bold text-sm">{{ struk.customer_id }} - {{ struk.name }}</div>
                      <div class="text-xs text-gray-500">
                        {{ getMonthName(struk.period_month) }} {{ struk.period_year }} | 
                        Total: Rp {{ formatRupiah(struk.total_tagihan) }}
                      </div>
                    </div>
                    <button 
                      @click="removeStruk(index)"
                      class="p-1 text-red-500 hover:bg-red-50 rounded-full"
                    >
                      <TrashIcon class="w-5 h-5" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Action Buttons -->
            <div class="flex items-center justify-between gap-3 pt-6 mt-6 border-t border-gray-100">
              <button 
                @click="resetAll"
                class="px-4 py-2 text-red-600 font-medium hover:bg-red-50 rounded-lg transition-colors"
              >
                Reset Semua
              </button>
              <div class="flex gap-3">
                <button 
                  @click="closeModal"
                  class="px-6 py-2.5 rounded-xl text-gray-600 font-bold hover:bg-gray-100 transition-colors border border-gray-200"
                >
                  Batal
                </button>
                <button 
                  @click="printStruk"
                  :disabled="strukList.length === 0"
                  class="px-6 py-2.5 rounded-xl bg-blue-500 text-white font-bold shadow-lg shadow-blue-500/30 hover:bg-blue-600 transition-all flex items-center gap-2 disabled:opacity-50"
                >
                  <PrinterIcon class="w-5 h-5" />
                  Cetak {{ strukList.length }} Struk
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Print Area: 6 Struk Grid -->
    <div id="print-area" class="print-only">
      <div class="struk-grid">
        <div v-for="(struk, index) in strukList" :key="index" class="struk-item">
          <!-- Header -->
          <div class="struk-header">
            <div class="struk-title">HIPPAMS TIRTO JOYO</div>
            <div class="struk-subtitle">GEMPOLPAYUNG, GEMPOLTUKLMOKO</div>
            <div class="struk-subtitle">SARIREJO LAMONGAN</div>
            <div class="struk-period-box">STRUK TAGIHAN AIR</div>
            <div class="struk-period">{{ getMonthName(struk.period_month) }} {{ struk.period_year }}</div>
          </div>
          
          <!-- Info -->
          <div class="struk-section">
            <div class="struk-row">
              <span>Tgl Cetak</span>
              <span>{{ struk.tgl_cetak }}</span>
            </div>
            <div class="struk-row">
              <span>ID Pelanggan</span>
              <span class="bold">{{ struk.customer_id }}</span>
            </div>
            <div class="struk-row">
              <span>Nama</span>
              <span class="bold">{{ struk.name }}</span>
            </div>
            <div class="struk-row">
              <span>Alamat</span>
              <span>{{ struk.address }}</span>
            </div>
          </div>
          
          <!-- Meter -->
          <div class="struk-section">
            <div class="struk-row">
              <span>Meter Awal</span>
              <span>{{ struk.meter_awal }}</span>
            </div>
            <div class="struk-row">
              <span>Meter Akhir</span>
              <span>{{ struk.meter_akhir }}</span>
            </div>
            <div class="struk-row bold">
              <span>Pemakaian</span>
              <span>{{ struk.jumlah_pakai }} M³</span>
            </div>
          </div>
          
          <!-- Tarif -->
          <div class="struk-section">
            <div class="struk-row-3">
              <span>PEMAKAIAN 1</span>
              <span>{{ struk.tarif_breakdown?.pemakaian1?.qty || 0 }} x 1.500</span>
              <span>Rp {{ formatRupiah(struk.tarif_breakdown?.pemakaian1?.subtotal || 0) }}</span>
            </div>
            <div class="struk-row-3">
              <span>PEMAKAIAN 2</span>
              <span>{{ struk.tarif_breakdown?.pemakaian2?.qty || 0 }} x 2.000</span>
              <span>Rp {{ formatRupiah(struk.tarif_breakdown?.pemakaian2?.subtotal || 0) }}</span>
            </div>
            <div class="struk-row-3">
              <span>PEMAKAIAN 3</span>
              <span>{{ struk.tarif_breakdown?.pemakaian3?.qty || 0 }} x 2.500</span>
              <span>Rp {{ formatRupiah(struk.tarif_breakdown?.pemakaian3?.subtotal || 0) }}</span>
            </div>
            <div class="struk-row">
              <span>ADMINISTRASI</span>
              <span>Rp {{ formatRupiah(struk.biaya_admin || 2000) }}</span>
            </div>
            <div class="struk-row bold mt-1">
              <span>TOTAL BIAYA</span>
              <span>Rp {{ formatRupiah(getTotalBiaya(struk)) }}</span>
            </div>
            <div :class="['struk-row', struk.tunggakan > 0 ? 'red bold' : '']">
              <span>TUNGGAKAN</span>
              <span>Rp {{ formatRupiah(struk.tunggakan || 0) }}</span>
            </div>
          </div>
          
          <!-- Total -->
          <div class="struk-total">
            <div class="struk-row bold">
              <span>TOTAL TAGIHAN</span>
              <span>Rp {{ formatRupiah(struk.total_tagihan) }}</span>
            </div>
            <div class="terbilang">{{ struk.terbilang }} rupiah</div>
          </div>
          
          <!-- Footer -->
          <div class="struk-footer">
            <div class="payment-info">PEMBAYARAN TERAKHIR TGL: 30 {{ getMonthName(struk.period_month) }}</div>
            <div>TERIMA KASIH TELAH MELAKUKAN</div>
            <div class="bold">PEMBAYARAN TEPAT WAKTU</div>
            <div class="signatures">
              <div>
                <div>BENDAHARA</div>
                <div class="sign-name">M. ROFI'I</div>
              </div>
              <div>
                <div>KETUA</div>
                <div class="sign-name">ACH. HABIBUR ROHMAN, S.E.</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
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

/* Hide print area on screen */
.print-only {
  display: none;
}

.no-print {
  display: block;
}

/* Print Styles for F4 paper with 6 receipts */
@media print {
  /* Remove browser headers/footers (URL, page numbers, date) */
  @page {
    size: 210mm 330mm; /* F4 Paper */
    margin: 5mm;
    /* Remove header and footer */
    margin-top: 0;
    margin-bottom: 0;
  }
  
  /* Hide absolutely everything first */
  html, body {
    margin: 0 !important;
    padding: 0 !important;
  }
  
  body * {
    visibility: hidden;
  }
  
  /* Hide all dashboard elements */
  .no-print,
  header,
  nav,
  aside,
  footer,
  .sidebar,
  .navbar,
  .toast,
  .modal-backdrop,
  [class*="admin"],
  h1, h2, h3, p:not(.print-only p) {
    display: none !important;
  }
  
  /* Only show print area */
  .print-only {
    display: block !important;
    visibility: visible !important;
    position: fixed !important;
    left: 0 !important;
    top: 0 !important;
    width: 210mm !important;
    height: 330mm !important;
    margin: 0 !important;
    padding: 0 !important;
    background: white !important;
    z-index: 99999 !important;
  }
  
  .print-only * {
    visibility: visible !important;
  }
  
  /* Grid: 2 columns x 3 rows = 6 receipts */
  .struk-grid {
    display: grid !important;
    grid-template-columns: repeat(2, 1fr) !important;
    grid-template-rows: repeat(3, 1fr) !important;
    gap: 1mm !important;
    width: 200mm !important;
    height: 330mm !important;
    margin: 0 !important;
    padding: 0 !important;
  }
  
  .struk-item {
    border: 1px solid #333 !important;
    padding: 1.5mm !important;
    font-family: Helvetica, Arial, sans-serif !important;
    font-size: 8pt !important;
    line-height: 1.2 !important;
    page-break-inside: avoid !important;
    overflow: hidden !important;
    background: white !important;
  }
  
  .struk-header {
    text-align: center;
    border-bottom: 1px dashed #333;
    padding-bottom: 1mm;
    margin-bottom: 1mm;
  }
  
  .struk-title {
    font-size: 11pt;
    font-weight: bold;
    color: #7c2d12;
  }
  
  .struk-subtitle {
    font-size: 8pt;
  }
  
  .struk-period-box {
    font-size: 10pt;
    font-weight: bold;
    background: #7c2d12 !important;
    color: white !important;
    padding: 1mm;
    margin-top: 1mm;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
  
  .struk-period {
    font-size: 9pt;
    font-weight: bold;
  }
  
  .struk-section {
    border-bottom: 1px dashed #333;
    padding-bottom: 0.5mm;
    margin-bottom: 0.5mm;
  }
  
  .struk-row {
    display: flex;
    justify-content: space-between;
  }
  
  .struk-row-3 {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
  }
  
  .bold {
    font-weight: bold;
  }
  
  .red {
    color: #dc2626 !important;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
  
  .struk-total {
    background: #fef3c7 !important;
    padding: 0.5mm 1mm;
    border: 1px solid #f59e0b;
    margin-bottom: 0.5mm;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
  
  .terbilang {
    font-size: 8pt;
    font-style: italic;
    text-transform: capitalize;
  }
  
  .struk-footer {
    text-align: center;
    border-top: 1px dashed #333;
    padding-top: 1mm;
    font-size: 8pt;
  }
  
  .payment-info {
    font-weight: bold;
    margin-bottom: 1mm;
  }
  
  .signatures {
    display: flex;
    justify-content: space-between;
    margin-top: 1mm;
    text-align: left;
  }
  
  .sign-name {
    margin-top: 4mm;
    font-weight: bold;
  }
}
</style>
