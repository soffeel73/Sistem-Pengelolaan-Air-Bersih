<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { XMarkIcon } from '@heroicons/vue/24/solid'
import { PlusIcon, MagnifyingGlassIcon } from '@heroicons/vue/24/outline'

// API configuration
const API_BASE = '/api/input_meter.php'

// State
const customers = ref([])
const isLoading = ref(false)

// Riwayat State (from Riwayat page)
const riwayatData = ref([])
const isLoadingRiwayat = ref(false)
const searchQuery = ref('')
const filterMonth = ref('')
const filterYear = ref('')

// Modal State
const showModal = ref(false)
const isEditing = ref(false)

// Pagination
const currentPage = ref(1)
const itemsPerPage = ref(10)
const totalItems = ref(0)
const totalPages = ref(0)

// Wilayah filter
const selectedWilayah = ref('')

// Form Data (same as admin)
const formData = ref({
  pelanggan_id: '',
  period_year: new Date().getFullYear(),
  period_month: new Date().getMonth() + 1,
  meter_awal: 0,
  meter_akhir: 0
})
const selectedCustomer = ref(null)
const formErrors = ref({})

// Month options
const monthOptions = [
  { value: 1, label: 'Januari' },
  { value: 2, label: 'Februari' },
  { value: 3, label: 'Maret' },
  { value: 4, label: 'April' },
  { value: 5, label: 'Mei' },
  { value: 6, label: 'Juni' },
  { value: 7, label: 'Juli' },
  { value: 8, label: 'Agustus' },
  { value: 9, label: 'September' },
  { value: 10, label: 'Oktober' },
  { value: 11, label: 'November' },
  { value: 12, label: 'Desember' }
]

// ==================== COMPUTED ====================
// Progressive tariff calculation (same as admin)
const jumlahPakai = computed(() => {
  const usage = formData.value.meter_akhir - formData.value.meter_awal
  return usage > 0 ? usage : 0
})

const BIAYA_ADMIN = 2000

const totalBiaya = computed(() => {
  const usage = jumlahPakai.value
  let biayaAir = 0
  
  // Block 1: 0-5 m3 @ Rp 1.500
  if (usage <= 5) {
    biayaAir = usage * 1500
  }
  // Block 2: >5-10 m3 @ Rp 2.000
  else if (usage <= 10) {
    biayaAir = (5 * 1500) + ((usage - 5) * 2000)
  }
  // Block 3: >10 m3 @ Rp 2.500
  else {
    biayaAir = (5 * 1500) + (5 * 2000) + ((usage - 10) * 2500)
  }
  
  // Add admin fee
  return biayaAir + BIAYA_ADMIN
})

// Get unique wilayah (addresses) from customers
const uniqueWilayah = computed(() => {
  const addresses = customers.value.map(c => c.address).filter(Boolean)
  return [...new Set(addresses)].sort()
})

// Filter customers by selected wilayah
const filteredCustomers = computed(() => {
  if (!selectedWilayah.value) {
    return customers.value
  }
  return customers.value.filter(c => c.address === selectedWilayah.value)
})

// Filter riwayat based on period (legacy - now handled by server)
const filteredRiwayat = computed(() => {
  return riwayatData.value
})

const goToPage = (page) => {
  if (page >= 1 && page <= totalPages.value) {
    currentPage.value = page
    fetchRiwayat()
  }
}

const resetFilter = () => {
  searchQuery.value = ''
  filterMonth.value = ''
  filterYear.value = ''
  currentPage.value = 1
  fetchRiwayat()
}

// Format period to readable month/year
const formatPeriod = (month, year) => {
  const monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 
                      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']
  return `${monthNames[month - 1]} ${year}`
}

// ==================== API FUNCTIONS ====================
const fetchCustomers = async () => {
  try {
    const response = await fetch(`${API_BASE}?action=pelanggans`)
    const data = await response.json()
    if (data.success) {
      customers.value = data.data.sort((a, b) => a.customer_id.localeCompare(b.customer_id))
    }
  } catch (error) {
    console.error('Failed to fetch customers:', error)
  }
}

// Fetch riwayat from API
const fetchRiwayat = async () => {
  isLoadingRiwayat.value = true
  try {
    // Get current petugas username
    const petugasId = localStorage.getItem('username') || 'petugas'
    
    const params = new URLSearchParams({
      petugas_id: petugasId,  // Filter by current petugas
      page: currentPage.value,
      limit: itemsPerPage.value
    })

    if (filterYear.value) params.append('year', filterYear.value)
    if (filterMonth.value) params.append('month', filterMonth.value)
    if (searchQuery.value) params.append('search', searchQuery.value)
    
    const response = await fetch(`${API_BASE}?${params.toString()}`)
    const data = await response.json()
    
    if (data.success) {
      // Map API response to component format
      riwayatData.value = data.data.map(item => ({
        id: item.id,
        customer_id: item.customer_id,
        nama: item.pelanggan_name,
        meteran_awal: parseInt(item.meter_awal),
        meteran_akhir: parseInt(item.meter_akhir),
        pemakaian: parseInt(item.jumlah_pakai),
        period_month: item.period_month,
        period_year: item.period_year,
        tanggal: item.created_at || new Date().toISOString(),
        petugas: petugasId
      }))

      if (data.pagination) {
        totalItems.value = data.pagination.total_items
        totalPages.value = data.pagination.total_pages
      }
    }
  } catch (error) {
    console.error('Failed to fetch riwayat:', error)
  } finally {
    isLoadingRiwayat.value = false
  }
}

const fetchMeterAwal = async () => {
  if (!formData.value.pelanggan_id) {
    formData.value.meter_awal = 0
    return
  }
  
  try {
    const params = new URLSearchParams({
      action: 'meter_awal',
      pelanggan_id: formData.value.pelanggan_id,
      year: formData.value.period_year,
      month: formData.value.period_month
    })
    
    const response = await fetch(`${API_BASE}?${params.toString()}`)
    const data = await response.json()
    if (data.success) {
      formData.value.meter_awal = data.meter_awal
    }
  } catch (error) {
    console.error('Failed to fetch meter awal:', error)
  }
}

// ==================== MODAL FUNCTIONS ====================
const openAddModal = () => {
  isEditing.value = false
  formData.value = {
    pelanggan_id: '',
    period_year: new Date().getFullYear(),
    period_month: new Date().getMonth() + 1,
    meter_awal: 0,
    meter_akhir: 0
  }
  selectedCustomer.value = null
  formErrors.value = {}
  showModal.value = true
}

const closeModal = () => {
  showModal.value = false
  formErrors.value = {}
}

const saveMeterReading = async () => {
  formErrors.value = {}
  
  // Validation
  if (!formData.value.pelanggan_id) {
    formErrors.value.pelanggan_id = 'Pelanggan wajib dipilih'
  }
  if (formData.value.meter_akhir < formData.value.meter_awal) {
    formErrors.value.meter_akhir = 'Meter akhir tidak boleh lebih kecil dari meter awal'
  }
  
  if (Object.keys(formErrors.value).length > 0) return

  isLoading.value = true
  try {
    const response = await fetch(API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...formData.value,
        petugas_id: localStorage.getItem('username') || 'petugas'
      })
    })
    const data = await response.json()
    
    if (data.success) {
      if (window.showToast) {
        window.showToast('Data input meter berhasil disimpan', 'success')
      }
      
      // Refresh customer data and riwayat
      await fetchCustomers()
      await fetchRiwayat()
      
      // Keep modal open, retain wilayah, reset customer selection for next input
      formData.value.pelanggan_id = ''
      formData.value.meter_awal = 0
      formData.value.meter_akhir = 0
      selectedCustomer.value = null
      formErrors.value = {}
    } else {
      if (window.showToast) {
        window.showToast(data.message || 'Gagal menyimpan data', 'error')
      }
      formErrors.value.general = data.message
    }
  } catch (error) {
    console.error('Error saving:', error)
    if (window.showToast) {
      window.showToast('Gagal menyimpan data input meter', 'error')
    }
  } finally {
    isLoading.value = false
  }
}

// Watch for customer selection
watch(() => formData.value.pelanggan_id, (newVal) => {
  if (newVal) {
    selectedCustomer.value = customers.value.find(c => c.id == newVal) || null
    if (!isEditing.value) {
      fetchMeterAwal()
    }
  } else {
    selectedCustomer.value = null
    formData.value.meter_awal = 0
  }
})

// Watch for period change
watch([() => formData.value.period_year, () => formData.value.period_month], () => {
  if (formData.value.pelanggan_id && !isEditing.value) {
    fetchMeterAwal()
  }
})

// Watch for wilayah change - reset customer selection
watch(selectedWilayah, () => {
  formData.value.pelanggan_id = ''
  selectedCustomer.value = null
  formData.value.meter_awal = 0
})

// Watch for filter change
watch([filterYear, filterMonth], () => {
  currentPage.value = 1
  fetchRiwayat()
})

// Debounced search
let searchTimeout
watch(searchQuery, () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    currentPage.value = 1
    fetchRiwayat()
  }, 500)
})

// Initialize
onMounted(() => {
  fetchCustomers()
  fetchRiwayat()
  
  // Auto-refresh riwayat every 30 seconds
  setInterval(() => {
    fetchRiwayat()
  }, 30000)
})
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div>
        <h2 class="text-2xl font-bold text-gray-900">Input Meter</h2>
        <p class="text-gray-500">Input data penggunaan air pelanggan bulanan (Petugas)</p>
      </div>
      <button 
        @click="openAddModal"
        class="inline-flex items-center gap-2 px-5 py-2.5 bg-primary text-white rounded-xl font-bold shadow-lg shadow-primary/30 hover:bg-teal-600 transition-all"
      >
        <PlusIcon class="w-5 h-5" />
        Tambah Input Meter
      </button>
    </div>

    <!-- Info Card -->
    <div class="bg-gradient-to-r from-blue-50 to-cyan-50 border-2 border-blue-200 rounded-xl p-6">
      <div class="flex items-start gap-4">
        <div class="flex-shrink-0 w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center">
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
        </div>
        <div class="flex-1">
          <h3 class="font-bold text-blue-900 text-lg mb-2">Panduan Input Meter</h3>
          <ul class="text-blue-700 space-y-1 text-sm">
            <li>• Klik tombol <strong>"Tambah Input Meter"</strong> untuk mulai input</li>
            <li>• Pilih pelanggan dari dropdown</li>
            <li>• Meter awal otomatis dari periode sebelumnya</li>
            <li>• Masukkan angka meter akhir bulan ini</li>
            <li>• Sistem otomatis menghitung pemakaian dan biaya dengan tarif progresif</li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal (100% Admin Style) -->
    <Teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" @click="closeModal"></div>
        
        <!-- Modal Content -->
        <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-2xl p-6 transform transition-all max-h-[90vh] overflow-y-auto">
          <!-- Close Button -->
          <button 
            @click="closeModal"
            class="absolute top-4 right-4 p-1 text-gray-400 hover:text-gray-600 transition-colors"
          >
            <XMarkIcon class="w-6 h-6" />
          </button>
          
          <!-- Header -->
          <h3 class="text-xl font-bold text-gray-900 mb-6">
            Tambah Input Meter Baru
          </h3>
          
          <!-- Form -->
          <form @submit.prevent="saveMeterReading" class="space-y-6">
            <!-- Wilayah Filter -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                <span class="flex items-center gap-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                  </svg>
                  Pilih Wilayah
                </span>
              </label>
              <select 
                v-model="selectedWilayah"
                class="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
              >
                <option value="">-- Semua Wilayah --</option>
                <option v-for="wilayah in uniqueWilayah" :key="wilayah" :value="wilayah">
                  {{ wilayah }} ({{ customers.filter(c => c.address === wilayah).length }} pelanggan)
                </option>
              </select>
              <p class="text-xs text-gray-400 mt-1">Filter pelanggan berdasarkan wilayah</p>
            </div>

            <!-- Pelanggan Selection -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Pilih Pelanggan</label>
              <select 
                v-model="formData.pelanggan_id"
                class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
                :class="[formErrors.pelanggan_id ? 'border-red-500' : 'border-gray-200']"
                :disabled="!selectedWilayah"
              >
                <option value="">{{ selectedWilayah ? '-- Pilih Pelanggan --' : '-- Pilih Wilayah Dulu --' }}</option>
                <option v-for="c in filteredCustomers" :key="c.id" :value="c.id">
                  {{ c.customer_id }} - {{ c.name }}
                </option>
              </select>
              <p v-if="formErrors.pelanggan_id" class="text-red-500 text-xs mt-1">{{ formErrors.pelanggan_id }}</p>
            </div>
            
            <!-- Customer Info (Auto-fill) -->
            <div v-if="selectedCustomer" class="p-4 bg-frozen/30 rounded-xl border border-frozen">
              <div class="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span class="text-gray-500">Nama:</span>
                  <span class="ml-2 font-bold text-gray-900">{{ selectedCustomer.name }}</span>
                </div>
                <div>
                  <span class="text-gray-500">Golongan:</span>
                  <span class="ml-2 font-bold text-gray-900">{{ selectedCustomer.type }}</span>
                </div>
                <div class="col-span-2">
                  <span class="text-gray-500">Alamat:</span>
                  <span class="ml-2 font-bold text-gray-900">{{ selectedCustomer.address }}</span>
                </div>
              </div>
            </div>
            
            <!-- Periode -->
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Bulan</label>
                <select 
                  v-model="formData.period_month"
                  class="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
                >
                  <option v-for="m in monthOptions" :key="m.value" :value="m.value">{{ m.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Tahun</label>
                <select 
                  v-model="formData.period_year"
                  class="w-full px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
                >
                  <option v-for="y in [2024, 2025, 2026, 2027]" :key="y" :value="y">{{ y }}</option>
                </select>
              </div>
            </div>
            
            <!-- Meter Readings -->
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Meter Awal (m³)</label>
                <input 
                  v-model.number="formData.meter_awal"
                  type="number"
                  min="0"
                  readonly
                  class="w-full px-4 py-2 border border-gray-200 rounded-lg bg-gray-100 cursor-not-allowed font-mono font-bold"
                >
                <p class="text-xs text-gray-400 mt-1">Auto dari periode sebelumnya</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Meter Akhir (m³)</label>
                <input 
                  v-model.number="formData.meter_akhir"
                  type="number"
                  min="0"
                  class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 font-mono font-bold"
                  :class="formErrors.meter_akhir ? 'border-red-500' : 'border-gray-200'"
                  placeholder="Masukkan angka meteran"
                >
                <p v-if="formErrors.meter_akhir" class="text-red-500 text-xs mt-1">{{ formErrors.meter_akhir }}</p>
              </div>
            </div>
            
            <!-- Live Calculation Preview -->
            <div class="p-4 bg-primary text-white rounded-xl">
              <div class="text-sm text-white/80 mb-3">Kalkulasi Real-time</div>
              <div class="grid grid-cols-2 gap-4 mb-3">
                <div>
                  <div class="text-xs uppercase tracking-wider opacity-70 mb-1">Jumlah Pakai</div>
                  <div class="text-2xl font-bold">{{ jumlahPakai }} <span class="text-sm font-normal">m³</span></div>
                </div>
                <div>
                  <div class="text-xs uppercase tracking-wider opacity-70 mb-1">Biaya Air</div>
                  <div class="text-xl font-bold">Rp {{ (totalBiaya - BIAYA_ADMIN).toLocaleString('id-ID') }}</div>
                </div>
              </div>
              <div class="pt-3 border-t border-white/20 space-y-2">
                <div class="flex justify-between text-sm">
                  <span class="opacity-80">Biaya Admin</span>
                  <span class="font-bold">Rp {{ BIAYA_ADMIN.toLocaleString('id-ID') }}</span>
                </div>
                <div class="flex justify-between text-lg pt-2 border-t border-white/20">
                  <span class="font-bold">Total Tagihan</span>
                  <span class="font-bold text-amber-400">Rp {{ totalBiaya.toLocaleString('id-ID') }}</span>
                </div>
              </div>
              <div class="mt-3 pt-3 border-t border-white/20 text-xs text-white/70">
                Tarif: 0-5m³ @Rp1.500 | 5-10m³ @Rp2.000 | >10m³ @Rp2.500 + Admin Rp2.000
              </div>
            </div>
            
            <!-- Buttons -->
            <div class="flex items-center justify-end gap-3 pt-4 border-t border-gray-100">
              <button 
                type="button"
                @click="closeModal"
                class="px-6 py-2.5 rounded-xl text-gray-600 font-bold hover:bg-gray-100 transition-colors border border-gray-200"
              >
                Batal
              </button>
              <button 
                type="submit"
                :disabled="isLoading"
                class="px-6 py-2.5 rounded-xl bg-primary text-white font-bold shadow-lg shadow-primary/30 hover:bg-teal-600 transition-all disabled:opacity-50"
              >
                {{ isLoading ? 'Menyimpan...' : 'Simpan' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Teleport>

    <!-- Riwayat Input Table -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
      <div class="p-6 border-b border-gray-100">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Riwayat Input Meteran</h3>
        
        <!-- Filter Section -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="relative">
            <MagnifyingGlassIcon class="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input 
              v-model="searchQuery"
              type="text" 
              placeholder="Cari ID Pelanggan atau Nama"
              class="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50"
            />
          </div>
          <div class="flex gap-2">
            <select 
              v-model="filterMonth"
              class="flex-1 px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
            >
              <option value="">Semua Bulan</option>
              <option v-for="m in monthOptions" :key="m.value" :value="m.value">{{ m.label }}</option>
            </select>
            <select 
              v-model="filterYear"
              class="flex-1 px-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
            >
              <option value="">Semua Tahun</option>
              <option v-for="y in [2024, 2025, 2026, 2027]" :key="y" :value="y">{{ y }}</option>
            </select>
          </div>
          <div>
            <button 
              @click="resetFilter"
              class="w-full px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium rounded-lg transition-colors"
            >
              Reset Filter
            </button>
          </div>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="isLoadingRiwayat" class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
      
      <!-- Table -->
      <div v-else-if="filteredRiwayat.length > 0" class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-frozen">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-bold text-gray-700 uppercase tracking-wider">Periode</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-gray-700 uppercase tracking-wider">ID Pelanggan</th>
              <th class="px-4 py-3 text-left text-xs font-bold text-gray-700 uppercase tracking-wider">Nama</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-gray-700 uppercase tracking-wider">Meteran Awal</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-gray-700 uppercase tracking-wider">Meteran Akhir</th>
              <th class="px-4 py-3 text-center text-xs font-bold text-gray-700 uppercase tracking-wider">Pemakaian</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr 
              v-for="item in filteredRiwayat" 
              :key="item.id"
              class="hover:bg-frozen/50 transition-colors"
            >
              <td class="px-4 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                {{ formatPeriod(item.period_month, item.period_year) }}
              </td>
              <td class="px-4 py-4 whitespace-nowrap">
                <span class="text-sm font-bold text-primary">{{ item.customer_id }}</span>
              </td>
              <td class="px-4 py-4 text-sm font-medium text-gray-900">{{ item.nama }}</td>
              <td class="px-4 py-4 whitespace-nowrap text-center text-sm text-gray-600">{{ item.meteran_awal }} m³</td>
              <td class="px-4 py-4 whitespace-nowrap text-center text-sm font-bold text-gray-900">{{ item.meteran_akhir }} m³</td>
              <td class="px-4 py-4 whitespace-nowrap text-center">
                <span class="px-3 py-1 bg-primary/10 text-primary font-bold text-sm rounded-full">
                  {{ item.pemakaian }} m³
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Empty State -->
      <div v-else class="p-12 text-center">
        <svg class="w-12 h-12 text-gray-300 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <p class="text-gray-500 font-medium">Tidak ada data riwayat</p>
        <p class="text-gray-400 text-sm mt-1">Data input meteran akan muncul di sini</p>
      </div>

      <!-- Footer Stats & Pagination -->
      <div v-if="riwayatData.length > 0" class="bg-frozen px-6 py-4 border-t border-gray-200 flex flex-col sm:flex-row items-center justify-between gap-4">
        <div class="text-sm text-gray-600">
          Menampilkan <span class="font-bold text-gray-900">{{ riwayatData.length }}</span> dari <span class="font-bold text-gray-900">{{ totalItems }}</span> entri
        </div>
        
        <!-- Pagination Controls -->
        <div v-if="totalPages > 1" class="flex items-center gap-2">
          <button 
            @click="goToPage(currentPage - 1)" 
            :disabled="currentPage === 1"
            class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Sebutuhnya
          </button>
          
          <template v-for="page in totalPages" :key="page">
            <button 
              v-if="page === 1 || page === totalPages || (page >= currentPage - 1 && page <= currentPage + 1)"
              @click="goToPage(page)"
              class="px-3 py-1.5 text-sm rounded-lg border transition-all"
              :class="page === currentPage ? 'bg-primary text-white border-primary font-bold shadow-md shadow-primary/20' : 'border-gray-200 hover:bg-gray-50 text-gray-600'"
            >
              {{ page }}
            </button>
            <span v-else-if="page === currentPage - 2 || page === currentPage + 2" class="text-gray-400 px-1">...</span>
          </template>
          
          <button 
            @click="goToPage(currentPage + 1)" 
            :disabled="currentPage === totalPages"
            class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Berikutnya
          </button>
        </div>

        <div class="text-sm text-gray-600">
          Total Pemakaian: <span class="font-bold text-primary">{{ riwayatData.reduce((sum, item) => sum + item.pemakaian, 0) }} m³</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* No custom styles needed - using Tailwind */
</style>
