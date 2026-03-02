<script setup>
import { ref, onMounted, computed } from 'vue'
import { ClockIcon, MagnifyingGlassIcon, CalendarIcon } from '@heroicons/vue/24/outline'

// API configuration
const API_BASE = '/api/input_meter.php'

// State
const riwayatData = ref([])
const isLoading = ref(false)
// Pagination
const currentPage = ref(1)
const itemsPerPage = ref(10)
const totalItems = ref(0)
const totalPages = ref(0)

// Fetch riwayat from API
const fetchRiwayat = async () => {
  isLoading.value = true
  try {
    // Get current petugas username
    const petugasId = localStorage.getItem('username') || 'petugas'
    
    const params = new URLSearchParams({
      petugas_id: petugasId,  // Filter by current petugas
      page: currentPage.value,
      limit: itemsPerPage.value
    })

    if (searchQuery.value) params.append('search', searchQuery.value)
    // Note: API doesn't seem to support 'date' filter directly in getMeterReadings, 
    // but it supports search. We'll use legacy filtering for date if needed, 
    // or just let it be for now since searching is more common.
    
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
    isLoading.value = false
  }
}

const goToPage = (page) => {
  if (page >= 1 && page <= totalPages.value) {
    currentPage.value = page
    fetchRiwayat()
  }
}

// Filter riwayat (Legacy date filter + server side results)
const filteredRiwayat = computed(() => {
  let filtered = riwayatData.value

  if (selectedDate.value) {
    filtered = filtered.filter(item => item.tanggal.startsWith(selectedDate.value))
  }

  return filtered
})

const resetFilter = () => {
  searchQuery.value = ''
  selectedDate.value = ''
  currentPage.value = 1
  fetchRiwayat()
}

// Watchers for server-side filter
import { watch } from 'vue'
let searchTimeout
watch(searchQuery, () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    currentPage.value = 1
    fetchRiwayat()
  }, 500)
})

// Fetch on mount and refresh every 30 seconds
onMounted(() => {
  fetchRiwayat()
  
  // Auto-refresh every 30 seconds
  setInterval(() => {
    fetchRiwayat()
  }, 30000)
})
</script>

<template>
  <div class="max-w-6xl mx-auto space-y-6">
    
    <!-- Header -->
    <div class="bg-gradient-to-r from-accent to-orange-600 rounded-2xl p-6 text-white shadow-xl">
      <div class="flex items-center gap-3 mb-2">
        <ClockIcon class="w-8 h-8" />
        <h2 class="text-2xl font-bold">Riwayat Input Meteran</h2>
      </div>
      <p class="text-white/90 text-sm">Daftar input meteran yang telah Anda lakukan</p>
    </div>

    <!-- Filter Section -->
    <div class="bg-white rounded-2xl shadow-xl border border-gray-100 p-6">
      <h3 class="text-lg font-bold text-gray-900 mb-4">Filter Data</h3>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-bold text-gray-700 mb-2">
            <MagnifyingGlassIcon class="w-4 h-4 inline mr-1" />
            Cari Pelanggan
          </label>
          <input 
            v-model="searchQuery"
            type="text" 
            placeholder="ID Pelanggan atau Nama"
            class="w-full px-4 py-3 bg-white border-2 border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-accent/50 focus:border-accent transition-all"
          />
        </div>
        <div>
          <label class="block text-sm font-bold text-gray-700 mb-2">
            <CalendarIcon class="w-4 h-4 inline mr-1" />
            Tanggal
          </label>
          <div class="flex gap-2">
            <input 
              v-model="selectedDate"
              type="date" 
              class="flex-1 px-4 py-3 bg-white border-2 border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-accent/50 focus:border-accent transition-all"
            />
            <button 
              @click="resetFilter"
              class="px-4 py-3 bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium rounded-xl transition-colors"
            >
              Reset
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Data Table -->
    <div class="bg-white rounded-2xl shadow-xl border border-gray-100 overflow-hidden">
      <!-- Loading State -->
      <div v-if="isLoading" class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-accent"></div>
      </div>
      
      <div v-else class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-frozen">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-bold text-gray-700 uppercase tracking-wider">Tanggal</th>
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
              <td class="px-4 py-4 whitespace-nowrap text-sm text-gray-600">
                {{ new Date(item.tanggal).toLocaleString('id-ID', { 
                  day: '2-digit', 
                  month: 'short', 
                  year: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit'
                }) }}
              </td>
              <td class="px-4 py-4 whitespace-nowrap">
                <span class="text-sm font-bold text-accent">{{ item.customer_id }}</span>
              </td>
              <td class="px-4 py-4 text-sm font-medium text-gray-900">{{ item.nama }}</td>
              <td class="px-4 py-4 whitespace-nowrap text-center text-sm text-gray-600">{{ item.meteran_awal }} m³</td>
              <td class="px-4 py-4 whitespace-nowrap text-center text-sm font-bold text-gray-900">{{ item.meteran_akhir }} m³</td>
              <td class="px-4 py-4 whitespace-nowrap text-center">
                <span class="px-3 py-1 bg-accent/10 text-accent font-bold text-sm rounded-full">
                  {{ item.pemakaian }} m³
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Empty State -->
      <div v-if="filteredRiwayat.length === 0" class="p-8 text-center">
        <ClockIcon class="w-12 h-12 text-gray-300 mx-auto mb-3" />
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
              :class="page === currentPage ? 'bg-accent text-white border-accent font-bold shadow-md shadow-accent/20' : 'border-gray-200 hover:bg-gray-50 text-gray-600'"
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
          Total Pemakaian: <span class="font-bold text-accent">{{ riwayatData.reduce((sum, item) => sum + item.pemakaian, 0) }} m³</span>
        </div>
      </div>
    </div>
  </div>
</template>
