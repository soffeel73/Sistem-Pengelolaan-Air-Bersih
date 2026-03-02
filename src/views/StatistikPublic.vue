<script setup>
import { ref, onMounted, computed } from 'vue'
import VueApexCharts from 'vue3-apexcharts'
import { BeakerIcon, UsersIcon, CheckBadgeIcon, ChevronLeftIcon, ChartBarIcon, MegaphoneIcon } from '@heroicons/vue/24/outline'

const isLoading = ref(true)
const statsData = ref({
  summary: {
    usage_current_year: 0,
    total_customers: 0,
    payment_compliance: 0
  },
  charts: {
    trend_labels: [],
    trend_data: [],
    arrears: [],
    distribution: []
  }
})

const fetchData = async () => {
  try {
    const response = await fetch('/api/public_api.php?action=public_stats')
    const res = await response.json()
    if (res.success) {
      statsData.value = res.data
    }
  } catch (error) {
    console.error('Failed to fetch public stats:', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  fetchData()
})

// Chart Options & Series
const trendOptions = computed(() => ({
  chart: { 
    id: 'trend-pakai', 
    toolbar: { show: false },
    animations: { enabled: true, easing: 'easeinout', speed: 1000 }
  },
  stroke: { curve: 'smooth', width: 3 },
  fill: {
    type: 'gradient',
    gradient: { shadeIntensity: 1, opacityFrom: 0.4, opacityTo: 0.1, stops: [0, 90, 100] }
  },
  colors: ['#0d9488'],
  xaxis: { categories: statsData.value.charts.trend_labels },
  tooltip: { theme: 'light' }
}))

const trendSeries = computed(() => [
  { name: 'Pemakaian', data: statsData.value.charts.trend_data }
])

const arrearsOptions = computed(() => ({
  chart: { id: 'tunggakan-publik', toolbar: { show: false } },
  plotOptions: { bar: { distributed: true, borderRadius: 4, horizontal: true } },
  colors: statsData.value.charts.arrears.map(i => i.total > 1000000 ? '#ef4444' : '#10b981'),
  xaxis: { 
    categories: statsData.value.charts.arrears.map(i => i.wilayah),
    labels: { formatter: (val) => 'Rp ' + val.toLocaleString('id-ID') }
  },
  legend: { show: false },
  tooltip: { theme: 'light' }
}))

const arrearsSeries = computed(() => [
  { name: 'Total Tunggakan', data: statsData.value.charts.arrears.map(i => i.total) }
])

const distOptions = computed(() => ({
  chart: { id: 'sebaran-publik' },
  labels: statsData.value.charts.distribution.map(i => i.wilayah),
  colors: ['#0d9488', '#0ea5e9', '#6366f1', '#f43f5e', '#eab308'],
  legend: { position: 'bottom' },
  plotOptions: { pie: { donut: { size: '70%' } } },
  tooltip: { theme: 'light' }
}))

const distSeries = computed(() => statsData.value.charts.distribution.map(i => i.total))
</script>

<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Hero Section -->
    <div class="relative bg-gradient-to-br from-[#2EC4B6] via-[#20B2AA] to-[#1a9a8f] py-24 md:py-32 text-white overflow-hidden">
      <!-- Background Pattern -->
      <div class="absolute inset-0 opacity-10">
        <div class="absolute inset-0 bg-pattern"></div>
      </div>
      
      <!-- Decorative Elements -->
      <div class="absolute top-20 left-10 w-64 h-64 bg-white/5 rounded-full blur-3xl"></div>
      <div class="absolute bottom-10 right-20 w-96 h-96 bg-white/5 rounded-full blur-3xl"></div>
      
      <!-- Back Link -->
      <div class="absolute top-6 left-4 md:left-10 z-20">
        <RouterLink to="/" class="inline-flex items-center gap-2 text-white/90 hover:text-white transition-colors bg-white/10 backdrop-blur-md px-4 py-2 rounded-full text-sm font-medium hover:bg-white/20 border border-white/20">
          <ChevronLeftIcon class="w-4 h-4" />
          Kembali ke Beranda
        </RouterLink>
      </div>

      <!-- Hero Content -->
      <div class="container mx-auto px-4 relative z-10 text-center">
        <div class="max-w-4xl mx-auto" data-aos="fade-up">
          <span class="inline-block px-4 py-2 bg-white/15 backdrop-blur-sm rounded-full text-sm font-medium mb-6 border border-white/20">
            Smart Air Transparency Dashboard
          </span>
          <h1 class="text-4xl md:text-5xl lg:text-6xl font-bold mb-6 leading-tight">
            Transparansi <span class="text-yellow-300">Statistik</span><br class="hidden sm:block"> HIPPAMS TIRTO JOYO
          </h1>
          <p class="text-lg md:text-xl text-white/90 max-w-3xl mx-auto leading-relaxed">
            Wujud keterbukaan dalam pengelolaan layanan air bersih untuk masyarakat <strong>Dusun Gempolpayung, Desa Gempoltukmloko.</strong>
          </p>
        </div>
      </div>

      <!-- Wave Divider -->
      <div class="absolute bottom-0 left-0 right-0">
        <svg viewBox="0 0 1440 120" fill="none" xmlns="http://www.w3.org/2000/svg" class="w-full h-auto">
          <path d="M0 120L60 110C120 100 240 80 360 70C480 60 600 60 720 65C840 70 960 80 1080 85C1200 90 1320 90 1380 90L1440 90V120H1380C1320 120 1200 120 1080 120C960 120 840 120 720 120C600 120 480 120 360 120C240 120 120 120 60 120H0Z" fill="#f9fafb"/>
        </svg>
      </div>
    </div>

    <!-- Summary Section -->
    <section class="py-12 bg-gray-50 -mt-10 relative z-20">
      <div class="container mx-auto px-4">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-6xl mx-auto">
          <!-- Usage -->
          <div class="bg-white rounded-2xl p-8 shadow-lg border border-gray-100 flex items-center gap-6 group hover:shadow-xl transition-all duration-300" data-aos="fade-up">
            <div class="w-16 h-16 bg-gradient-to-br from-[#2EC4B6] to-[#20B2AA] rounded-xl flex items-center justify-center text-white shadow-lg shadow-teal-200 group-hover:scale-110 transition-transform">
              <BeakerIcon class="w-8 h-8" />
            </div>
            <div>
              <div class="text-sm font-bold text-gray-400 uppercase tracking-widest mb-1">Total Pemakaian Air</div>
              <div class="text-3xl font-black text-gray-800">
                {{ isLoading ? '...' : statsData.summary.usage_current_year.toLocaleString('id-ID') }} <span class="text-base font-medium text-gray-400">m³</span>
              </div>
            </div>
          </div>

          <!-- Customers -->
          <div class="bg-white rounded-2xl p-8 shadow-lg border border-gray-100 flex items-center gap-6 group hover:shadow-xl transition-all duration-300" data-aos="fade-up" data-aos-delay="100">
            <div class="w-16 h-16 bg-gradient-to-br from-blue-400 to-indigo-500 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-200 group-hover:scale-110 transition-transform">
              <UsersIcon class="w-8 h-8" />
            </div>
            <div>
              <div class="text-sm font-bold text-gray-400 uppercase tracking-widest mb-1">Pelanggan</div>
              <div class="text-3xl font-black text-gray-800">
                {{ isLoading ? '...' : statsData.summary.total_customers.toLocaleString('id-ID') }} <span class="text-base font-medium text-gray-400">Rumah</span>
              </div>
            </div>
          </div>

          <!-- Compliance -->
          <div class="bg-white rounded-2xl p-8 shadow-lg border border-gray-100 flex items-center gap-6 group hover:shadow-xl transition-all duration-300" data-aos="fade-up" data-aos-delay="200">
            <div class="w-16 h-16 bg-gradient-to-br from-emerald-400 to-teal-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-emerald-200 group-hover:scale-110 transition-transform">
              <CheckBadgeIcon class="w-8 h-8" />
            </div>
            <div>
              <div class="text-sm font-bold text-gray-400 uppercase tracking-widest mb-1">Kelancaran</div>
              <div class="text-3xl font-black text-gray-800">
                80<span class="text-teal-500">%</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Analytics Section -->
    <section class="py-20 bg-white">
      <div class="container mx-auto px-4">
        <div class="text-center max-w-3xl mx-auto mb-16" data-aos="fade-up">
          <span class="inline-block px-4 py-2 bg-[#2EC4B6]/10 text-[#2EC4B6] rounded-full text-sm font-semibold mb-4">
            <ChartBarIcon class="w-4 h-4 inline mr-1" />
            Analitik Detail
          </span>
          <h2 class="text-3xl md:text-4xl font-bold text-gray-800 mb-4">Visualisasi Data Layanan</h2>
          <p class="text-gray-600">Terbuka untuk umum sebagai monitoring kolektif demi kualitas layanan yang lebih baik.</p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-16 max-w-6xl mx-auto">
          <!-- Trend Chart -->
          <div class="bg-white rounded-3xl p-8 shadow-xl border border-gray-50 flex flex-col" data-aos="fade-right">
            <div class="mb-6 flex items-center justify-between">
              <h3 class="text-2xl font-bold text-gray-800">📊 Tren Pemakaian</h3>
              <span class="text-xs font-bold text-teal-600 bg-teal-50 px-3 py-1 rounded-full uppercase">Update Bulanan</span>
            </div>
            <div v-if="isLoading" class="h-64 bg-gray-50 animate-pulse rounded-2xl"></div>
            <VueApexCharts v-else height="320" type="area" :options="trendOptions" :series="trendSeries" />
            <p class="mt-6 text-sm text-gray-500 leading-relaxed italic">
              * Menampilkan akumulasi konsumsi air m³ seluruh pelanggan desa per periode bulan.
            </p>
          </div>

          <!-- Arrears Chart -->
          <div class="bg-white rounded-3xl p-8 shadow-xl border border-gray-50 flex flex-col" data-aos="fade-left">
            <div class="mb-6 flex items-center justify-between">
              <h3 class="text-2xl font-bold text-gray-800">📉 Status Tunggakan</h3>
              <span class="text-xs font-bold text-orange-600 bg-orange-50 px-3 py-1 rounded-full uppercase">Per Wilayah</span>
            </div>
            <div v-if="isLoading" class="h-64 bg-gray-50 animate-pulse rounded-2xl"></div>
            <VueApexCharts v-else height="320" type="bar" :options="arrearsOptions" :series="arrearsSeries" />
            <p class="mt-6 text-sm text-gray-500 leading-relaxed italic text-center">
              Data bersifat agregat (akumulasi) per wilayah untuk menjaga privasi personal warga.
            </p>
          </div>

          <!-- Distribution -->
          <div class="bg-white rounded-3xl p-8 shadow-xl border border-gray-50 lg:col-span-2" data-aos="fade-up">
            <div class="grid md:grid-cols-2 gap-10 items-center">
              <div class="space-y-6">
                <div>
                  <h3 class="text-2xl font-bold text-gray-800 mb-3">📍 Sebaran Pelanggan</h3>
                  <p class="text-gray-600 leading-relaxed">Persentase kepadatan pengguna layanan HIPPAMS di setiap wilayah layanan desa.</p>
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-12 gap-y-4">
                  <div v-for="item in statsData.charts.distribution.slice(0, 8)" :key="item.wilayah" class="flex items-center justify-between p-3 bg-gray-50 rounded-xl border border-gray-100">
                    <span class="text-gray-700 font-semibold">{{ item.wilayah }}</span>
                    <span class="text-teal-600 font-black ml-8 pr-1 shrink-0">{{ item.total }} KK</span>
                  </div>
                </div>
              </div>
              <div class="flex justify-center">
                <div v-if="isLoading" class="h-64 bg-gray-50 animate-pulse rounded-full w-64"></div>
                <VueApexCharts v-else height="380" width="100%" type="donut" :options="distOptions" :series="distSeries" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Footer CTA -->
    <section class="py-24 bg-gradient-to-br from-[#2EC4B6] via-[#20B2AA] to-[#1a9a8f] text-white">
      <div class="container mx-auto px-4 text-center" data-aos="fade-up">
        <h2 class="text-4xl md:text-5xl font-black mb-8">Bersama Wujudkan Transparansi</h2>
        <p class="text-white/90 mb-12 max-w-2xl mx-auto text-xl leading-relaxed">
          Laporkan jika terjadi kendala layanan atau berikan saran untuk kemajuan tata kelola air desa kita tercinta.
        </p>
        <div class="flex flex-col sm:flex-row items-center justify-center gap-6">
          <RouterLink to="/lapor-keluhan" class="inline-flex items-center gap-2 text-white/90 hover:text-white transition-colors bg-white/10 backdrop-blur-md px-4 py-2 rounded-full text-sm font-medium hover:bg-white/20 border border-white/20"">
            <MegaphoneIcon class="w-6 h-6 group-hover:rotate-12 transition-transform" />
            Lapor Keluhan
          </RouterLink>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.bg-pattern {
  background-image: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='1'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
}

:deep(.apexcharts-tooltip) {
  border-radius: 12px !important;
  border: none !important;
  box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.1) !important;
}

[data-aos="fade-up"] { animation: fadeUp 0.6s ease-out forwards; }
[data-aos="fade-right"] { animation: fadeRight 0.6s ease-out forwards; }
[data-aos="fade-left"] { animation: fadeLeft 0.6s ease-out forwards; }

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(30px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes fadeRight {
  from { opacity: 0; transform: translateX(-30px); }
  to { opacity: 1; transform: translateX(0); }
}

@keyframes fadeLeft {
  from { opacity: 0; transform: translateX(30px); }
  to { opacity: 1; transform: translateX(0); }
}
</style>
