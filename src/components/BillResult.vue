<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'

const router = useRouter()

const props = defineProps({
  data: {
    type: Object,
    default: null
  }
})
const emit = defineEmits(['back'])

// Reactive data yang bisa diisi dari props atau localStorage
const billData = ref(null)

onMounted(() => {
  // Prioritaskan props, fallback ke localStorage
  if (props.data) {
    billData.value = props.data
  } else {
    const storedData = localStorage.getItem('bill_data')
    if (storedData) {
      try {
        billData.value = JSON.parse(storedData)
      } catch (e) {
        console.error('Error parsing bill data:', e)
      }
    }
  }
})

// Fungsi navigasi kembali
const goBack = () => {
  // Hapus data dari localStorage setelah kembali
  localStorage.removeItem('bill_data')
  router.push('/')
}

// Modal states
const showPaymentModal = ref(false)
const showPaymentMethodsModal = ref(false)

// Helper functions
const formatRupiah = (value) => {
  if (!value && value !== 0) return 'Rp 0'
  return 'Rp ' + parseFloat(value).toLocaleString('id-ID', { maximumFractionDigits: 0 })
}

const getGolonganLabel = (type) => {
  const labels = {
    'R1': 'R1 - Sosial',
    'R2': 'R2 - Rumah Tangga',
    'N1': 'N1 - Niaga',
    'S1': 'S1 - Sosial Khusus'
  }
  return labels[type] || type
}

// Biaya administrasi tetap
const ADMIN_FEE = 2000

// Computed bill costs 
const costs = computed(() => {
  if (!billData.value?.tagihan_terbaru) return []
  const bill = billData.value.tagihan_terbaru
  // Biaya pemakaian air murni = total_biaya - admin fee
  const biayaAirMurni = bill.biaya - ADMIN_FEE
  return [
    { item: 'Biaya Pemakaian Air', amount: formatRupiah(biayaAirMurni) },
    { item: 'Biaya Administrasi', amount: formatRupiah(ADMIN_FEE) },
    { item: 'Tunggakan', amount: formatRupiah(bill.tunggakan), textClass: bill.tunggakan > 0 ? 'text-amber-600' : 'text-green-600' },
  ]
})

const totalTagihan = computed(() => {
  if (!billData.value?.tagihan_terbaru) return 0
  const bill = billData.value.tagihan_terbaru
  // Total = biaya air (sudah termasuk admin) + tunggakan
  return bill.biaya + bill.tunggakan
})

const statusBayar = computed(() => {
  if (!billData.value?.tagihan_terbaru) return 'unknown'
  return billData.value.tagihan_terbaru.status
})

// Computed total pemakaian from all months in tagihan_list
const totalPemakaian = computed(() => {
  if (!billData.value?.tagihan_list) return 0
  return billData.value.tagihan_list.reduce((sum, tagihan) => sum + tagihan.pemakaian, 0)
})

// Action handlers
const handleDownloadBill = () => {
  if (!billData.value) return
  
  const doc = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: 'a4'
  })
  
  const pageWidth = doc.internal.pageSize.getWidth()
  const margin = 20
  let yPos = 20
  
  // ===== HEADER SECTION =====
  // Header background
  doc.setFillColor(16, 79, 71) // #104F47
  doc.rect(0, 0, pageWidth, 50, 'F')
  
  // Header accent line
  doc.setFillColor(46, 196, 182) // #2EC4B6
  doc.rect(0, 50, pageWidth, 3, 'F')
  
  // Title
  doc.setTextColor(255, 255, 255)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(22)
  doc.text('STRUK TAGIHAN AIR', pageWidth / 2, 25, { align: 'center' })
  
  // Subtitle
  doc.setFontSize(12)
  doc.setFont('helvetica', 'normal')
  doc.text('HIPPAMS Tirto Joyo Gempolpayung', pageWidth / 2, 35, { align: 'center' })
  
  // Period badge
  doc.setFontSize(10)
  doc.text(`Periode: ${billData.value?.tagihan_terbaru?.periode || '-'}`, pageWidth / 2, 45, { align: 'center' })
  
  yPos = 65
  
  // ===== CUSTOMER INFO SECTION =====
  doc.setFillColor(240, 251, 250) // Light teal background
  doc.rect(margin, yPos - 5, pageWidth - (margin * 2), 40, 'F')
  
  // Border
  doc.setDrawColor(46, 196, 182)
  doc.setLineWidth(0.5)
  doc.rect(margin, yPos - 5, pageWidth - (margin * 2), 40, 'S')
  
  doc.setTextColor(16, 79, 71)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(11)
  doc.text('INFORMASI PELANGGAN', margin + 5, yPos + 3)
  
  yPos += 12
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(10)
  doc.setTextColor(60, 60, 60)
  
  // Customer details in two columns
  const leftCol = margin + 5
  const rightCol = pageWidth / 2 + 10
  
  doc.setFont('helvetica', 'bold')
  doc.text('ID Pelanggan:', leftCol, yPos)
  doc.setFont('helvetica', 'normal')
  doc.text(billData.value?.customer_id || '-', leftCol + 35, yPos)
  
  doc.setFont('helvetica', 'bold')
  doc.text('Golongan:', rightCol, yPos)
  doc.setFont('helvetica', 'normal')
  doc.text(getGolonganLabel(billData.value?.golongan), rightCol + 25, yPos)
  
  yPos += 8
  doc.setFont('helvetica', 'bold')
  doc.text('Nama:', leftCol, yPos)
  doc.setFont('helvetica', 'normal')
  doc.text(billData.value?.nama || '-', leftCol + 35, yPos)
  
  yPos += 8
  doc.setFont('helvetica', 'bold')
  doc.text('Alamat:', leftCol, yPos)
  doc.setFont('helvetica', 'normal')
  const alamat = billData.value?.alamat || '-'
  const splitAlamat = doc.splitTextToSize(alamat, 120)
  doc.text(splitAlamat, leftCol + 35, yPos)
  
  yPos += 20
  
  // ===== BILLING TABLE =====
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(11)
  doc.setTextColor(16, 79, 71)
  doc.text('RINCIAN TAGIHAN', margin, yPos)
  yPos += 8
  
  // Prepare table data
  const bill = billData.value?.tagihan_terbaru
  const biayaAirMurni = bill ? bill.biaya - ADMIN_FEE : 0
  
  const tableData = [
    ['Biaya Pemakaian Air', `${bill?.pemakaian || 0} m³`, formatRupiah(biayaAirMurni)],
    ['Biaya Administrasi', '-', formatRupiah(ADMIN_FEE)],
    ['Tunggakan Bulan Sebelumnya', '-', formatRupiah(bill?.tunggakan || 0)]
  ]
  
  autoTable(doc, {
    startY: yPos,
    head: [['Keterangan', 'Volume', 'Jumlah']],
    body: tableData,
    margin: { left: margin, right: margin },
    theme: 'grid',
    headStyles: {
      fillColor: [16, 79, 71],
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      fontSize: 10,
      halign: 'center'
    },
    bodyStyles: {
      fontSize: 10,
      textColor: [60, 60, 60]
    },
    columnStyles: {
      0: { halign: 'left', cellWidth: 80 },
      1: { halign: 'center', cellWidth: 35 },
      2: { halign: 'right', cellWidth: 55 }
    },
    alternateRowStyles: {
      fillColor: [248, 250, 252]
    }
  })
  
  yPos = doc.lastAutoTable.finalY + 5
  
  // ===== TOTAL SECTION =====
  doc.setFillColor(255, 191, 105) // #FFBF69
  doc.rect(margin, yPos, pageWidth - (margin * 2), 20, 'F')
  
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(12)
  doc.setTextColor(60, 60, 60)
  doc.text('TOTAL TAGIHAN', margin + 5, yPos + 13)
  
  doc.setFontSize(16)
  doc.setTextColor(16, 79, 71)
  doc.text(formatRupiah(totalTagihan.value), pageWidth - margin - 5, yPos + 13, { align: 'right' })
  
  yPos += 30
  
  // ===== STATUS BADGE =====
  const isPaid = statusBayar.value === 'paid'
  const statusColor = isPaid ? [34, 197, 94] : [239, 68, 68] // green or red
  const statusText = isPaid ? 'LUNAS' : 'BELUM BAYAR'
  
  doc.setFillColor(...statusColor)
  doc.roundedRect(pageWidth / 2 - 25, yPos, 50, 12, 3, 3, 'F')
  doc.setTextColor(255, 255, 255)
  doc.setFontSize(10)
  doc.setFont('helvetica', 'bold')
  doc.text(statusText, pageWidth / 2, yPos + 8, { align: 'center' })
  
  yPos += 25
  
  // ===== PAYMENT INFO =====
  doc.setFillColor(254, 243, 199) // Amber bg
  doc.rect(margin, yPos, pageWidth - (margin * 2), 30, 'F')
  doc.setDrawColor(251, 191, 36)
  doc.rect(margin, yPos, pageWidth - (margin * 2), 30, 'S')
  
  doc.setTextColor(146, 64, 14)
  doc.setFontSize(9)
  doc.setFont('helvetica', 'bold')
  doc.text('INFORMASI PEMBAYARAN:', margin + 5, yPos + 8)
  doc.setFont('helvetica', 'normal')
  doc.text('• Pembayaran dapat dilakukan di Bendahara atau melalui Transfer Bank', margin + 5, yPos + 16)
  doc.text('• Tidak melakukan pembayaran 3 bulan berturut-turut akan dilakukan pemutusan saluran air', margin + 5, yPos + 23)
  
  yPos += 40
  
  // ===== FOOTER =====
  const footerY = 280
  doc.setDrawColor(200, 200, 200)
  doc.setLineWidth(0.3)
  doc.line(margin, footerY - 10, pageWidth - margin, footerY - 10)
  
  doc.setTextColor(150, 150, 150)
  doc.setFontSize(8)
  doc.setFont('helvetica', 'normal')
  
  const today = new Date().toLocaleDateString('id-ID', { 
    day: 'numeric', 
    month: 'long', 
    year: 'numeric' 
  })
  doc.text(`Dicetak pada: ${today}`, margin, footerY - 3)
  doc.text('HIPPAMS Tirto Joyo Gempolpayung', pageWidth - margin, footerY - 3, { align: 'right' })
  
  doc.setTextColor(46, 196, 182)
  doc.setFontSize(9)
  doc.text('Terima kasih atas kepercayaan Anda!', pageWidth / 2, footerY + 5, { align: 'center' })
  
  // Save PDF
  const filename = `Tagihan-${billData.value?.customer_id}-${billData.value?.tagihan_terbaru?.periode || 'unknown'}.pdf`
  doc.save(filename)
}

const handlePayNow = () => {
  showPaymentModal.value = true
}

const handleShowPaymentMethods = () => {
  showPaymentMethodsModal.value = true
}

</script>

<template>
  <div class="min-h-screen bg-[#F0FBFA] pt-24 pb-12 font-sans text-gray-800">
    <div class="container mx-auto px-4 lg:px-8">
      
      <!-- Top Navigation & Header -->
      <div class="mb-8">
        <button @click="goBack" class="mb-4 flex items-center gap-2 text-[#2EC4B6] hover:text-teal-700 transition-colors font-medium text-sm">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
          Kembali ke Beranda
        </button>
        
        <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 mb-1">Hasil Pencarian Tagihan</h1>
            <p class="text-gray-500 text-sm">Menampilkan detail tagihan untuk {{ billData?.customer_id || 'N/A' }}</p>
          </div>
          
        </div>
      </div>

      <div v-if="billData" class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        <!-- Left Column: Bill Details -->
        <div class="lg:col-span-2 space-y-8">
          
          <!-- Customer Card -->
          <div class="bg-[#104F47] rounded-2xl p-6 relative overflow-hidden text-white shadow-lg">
             <!-- Background Pattern -->
             <div class="absolute inset-0 opacity-10" style="background-image: radial-gradient(circle at 2px 2px, white 1px, transparent 0); background-size: 20px 20px;"></div>
             
             <div class="relative z-10">
                <div class="flex justify-between items-start mb-4">
                  <div>
                    <div class="text-[#FFBF69] text-sm font-medium mb-1">ID Pelanggan: {{ billData.customer_id }}</div>
                    <h2 class="text-3xl font-bold">{{ billData.nama }}</h2>
                  </div>
                  <span class="px-3 py-1 rounded-full bg-white/20 backdrop-blur-sm text-xs border border-white/20">
                    Golongan {{ getGolonganLabel(billData.golongan) }}
                  </span>
                </div>
                <div class="flex items-center gap-2 text-white/80 text-sm">
                   <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
                   {{ billData.alamat }}
                </div>
             </div>
          </div>

          <!-- Period & Status - List of Months -->
          <div v-if="billData.tagihan_list && billData.tagihan_list.length > 0" class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
             <div class="flex items-center gap-2 mb-4">
               <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
               <h3 class="text-gray-900 font-bold">Periode Tagihan</h3>
             </div>
             
             <!-- List of months with status badges -->
             <div class="space-y-3">
               <div 
                 v-for="(tagihan, index) in billData.tagihan_list" 
                 :key="index"
                 class="flex items-center justify-between p-3 rounded-xl transition-all"
                 :class="tagihan.status === 'paid' ? 'bg-green-50 border border-green-100' : 'bg-orange-50 border border-orange-100'"
               >
                 <div class="flex items-center gap-3">
                   <div 
                     class="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold text-sm"
                     :class="tagihan.status === 'paid' ? 'bg-green-500' : 'bg-[#FF9F1C]'"
                   >
                     {{ tagihan.periode_short }}
                   </div>
                   <div>
                     <div class="font-semibold text-gray-900">{{ tagihan.periode }}</div>
                     <div class="text-xs text-gray-500">Biaya: {{ formatRupiah(tagihan.biaya) }}</div>
                   </div>
                 </div>
                 <span 
                   class="px-3 py-1 rounded-full text-xs font-bold"
                   :class="tagihan.status === 'paid' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'"
                 >
                   {{ tagihan.status === 'paid' ? 'Lunas' : 'Belum Bayar' }}
                 </span>
               </div>
             </div>
             
             <!-- Extra unpaid months indicator -->
             <div v-if="billData.extra_unpaid_months > 0" class="mt-4 pt-4 border-t border-gray-100">
               <div class="flex items-center gap-2 text-amber-600">
                 <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>
                 <span class="text-sm font-medium">+ {{ billData.extra_unpaid_months }} Bulan sebelumnya</span>
               </div>
             </div>
          </div>

          <!-- Usage Detail - Dynamic List -->
          <div v-if="billData.tagihan_list && billData.tagihan_list.length > 0">
            <h3 class="flex items-center gap-2 text-gray-900 font-bold mb-4">
               <svg class="w-5 h-5 text-[#2EC4B6]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
               Detail Pemakaian
            </h3>
            <div class="bg-white rounded-2xl p-4 shadow-sm border border-gray-100">
              <div class="space-y-3">
                <div 
                  v-for="(tagihan, index) in billData.tagihan_list" 
                  :key="'usage-' + index"
                  class="flex items-center justify-between p-3 bg-[#E0F7FA] rounded-xl border border-[#B2EBF2]"
                >
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 bg-[#2EC4B6] rounded-full flex items-center justify-center text-white font-bold text-sm">
                      {{ tagihan.periode_short }}
                    </div>
                    <span class="font-medium text-gray-700">{{ tagihan.periode }}</span>
                  </div>
                  <div class="text-xl font-bold text-[#006064]">
                    {{ tagihan.pemakaian }} <span class="text-sm text-[#00838F]/70 font-normal">m³</span>
                  </div>
                </div>
              </div>
              
              <!-- Total usage summary -->
              <div class="mt-4 pt-4 border-t border-[#B2EBF2] flex justify-between items-center">
                <span class="text-sm font-medium text-[#00838F]">Total Pemakaian ({{ billData.tagihan_list.length }} bulan)</span>
                <span class="text-lg font-bold text-[#006064]">
                  {{ totalPemakaian }} <span class="text-sm text-[#00838F]/70 font-normal">m³</span>
                </span>
              </div>
            </div>
          </div>

          <!-- No Bill Data -->
          <div v-else class="bg-white rounded-2xl p-8 text-center shadow-sm border border-gray-100">
            <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
            </div>
            <h3 class="font-bold text-gray-900 mb-2">Belum Ada Tagihan</h3>
            <p class="text-gray-500 text-sm">Pelanggan ini belum memiliki data tagihan.</p>
          </div>

          <!-- Cost Detail -->
          <div v-if="billData.tagihan_terbaru">
             <h3 class="flex items-center gap-2 text-gray-900 font-bold mb-4">
               <svg class="w-5 h-5 text-[#2EC4B6]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path></svg>
               Rincian Biaya
            </h3>
            <div class="bg-white rounded-2xl border border-gray-100 overflow-hidden">
               <div class="p-6 space-y-4">
                  <div class="flex justify-between text-xs font-bold text-gray-400 uppercase tracking-wilder border-b border-gray-50 pb-2">
                     <span>Keterangan</span>
                     <span>Jumlah</span>
                  </div>
                  <div v-for="(cost, i) in costs" :key="i" class="flex justify-between items-center text-sm">
                     <span class="text-gray-700 font-medium">{{ cost.item }}</span>
                     <span class="text-gray-900 font-bold" :class="cost.textClass">{{ cost.amount }}</span>
                  </div>
               </div>
               <div class="bg-gray-50 p-6 flex justify-between items-center border-t border-gray-100">
                  <span class="text-gray-800 font-bold">Total Tagihan</span>
                  <span class="text-2xl font-bold text-[#2EC4B6]">{{ formatRupiah(totalTagihan) }}</span>
               </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-6">
               <button @click="handleDownloadBill" class="py-4 rounded-xl border-2 border-[#FFBF69] text-[#F3A74C] font-bold hover:bg-orange-50 transition-colors flex justify-center items-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>
                  Download Tagihan
               </button>
               <button @click="handlePayNow" class="py-4 rounded-xl bg-gradient-to-r from-[#FF9F1C] to-[#F3A74C] text-white font-bold hover:shadow-lg hover:shadow-orange-500/30 transition-all flex justify-center items-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>
                  Bayar Sekarang
               </button>
            </div>
          </div>

        </div>

        <!-- Right Column: Sidebar -->
        <div class="space-y-6">
           <!-- Total Unpaid Alert -->
           <div v-if="billData.total_belum_bayar > 0" class="bg-amber-50 border border-amber-200 rounded-2xl p-6">
             <div class="flex items-center gap-3 mb-2">
               <div class="w-10 h-10 bg-amber-500 rounded-full flex items-center justify-center text-white">
                 <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>
               </div>
               <div>
                 <div class="font-bold text-amber-800">Total Belum Dibayar</div>
                 <div class="text-xs text-amber-600">{{ billData.jumlah_tagihan_tertunggak }} tagihan tertunggak</div>
               </div>
             </div>
             <div class="text-2xl font-bold text-amber-600">{{ formatRupiah(billData.total_belum_bayar) }}</div>
           </div>

           <!-- Info Box -->
           <div class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
              <h3 class="font-bold text-gray-900 mb-4">Informasi Penting</h3>
              <ul class="space-y-4">
                 <li class="flex gap-3 items-start">
                    <div class="w-6 h-6 rounded-full bg-[#FF9F1C] flex-shrink-0 flex items-center justify-center text-white text-xs font-bold font-serif italic">i</div>
                    <p class="text-xs text-gray-500 leading-relaxed">
                        Tidak melakukan pembayaran 3 bulan berturut-turut akan dilakukan pemutusan saluran air.
                    </p>
                 </li>
                 <li class="flex gap-3 items-start">
                    <div class="w-6 h-6 rounded-full bg-[#FF9F1C] flex-shrink-0 flex items-center justify-center text-white text-xs font-bold font-serif italic">i</div>
                    <p class="text-xs text-gray-500 leading-relaxed">
                        Pembayaran terakhir tanggal 30 setiap bulan.
                    </p>
                 </li>
                 <li class="flex gap-3 items-start">
                    <div class="w-6 h-6 rounded-full bg-[#2EC4B6] flex-shrink-0 flex items-center justify-center text-white text-xs font-bold">?</div>
                     <p class="text-xs text-gray-500 leading-relaxed">
                        Jika meteran air Anda mengalami kerusakan, segera hubungi <a href="#" class="text-[#2EC4B6] font-bold hover:underline">Customer Service</a>.
                    </p>
                 </li>
              </ul>
           </div>

           <!-- Promo Banner -->
           <div class="bg-[#107C6F] rounded-2xl p-6 text-white relative overflow-hidden shadow-lg">
              <div class="relative z-10">
                 <h3 class="text-xl font-bold mb-1">Bayar Lebih Hemat!</h3>
                 <p class="text-white/80 text-xs mb-4 leading-relaxed">
                    Dapatkan kemudahan pembayaran via e-Wallet atau transfer bank.
                 </p>
                 <button @click="handleShowPaymentMethods" class="bg-white text-[#107C6F] text-xs font-bold py-2 px-4 rounded-lg shadow-sm hover:bg-gray-50 transition-colors">
                    Lihat Cara Bayar
                 </button>
              </div>
              <div class="absolute top-4 right-4 text-white/10">
                 <svg class="w-24 h-24 transform rotate-12" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1.41 16.09V20h-2.67v-1.93c-1.71-.36-3.16-1.46-3.27-3.4h1.96c.1 1.05 1.18 1.91 2.53 1.91 1.38 0 2.29-.9 2.29-1.95 0-2.48-5.9-2.22-5.9-6.35 0-1.89 1.4-3.08 3.06-3.41V4h2.67v1.91c1.81.44 2.87 1.76 2.97 3.23h-2.02c-.13-.85-.92-1.52-2.16-1.52-1.29 0-2.18.91-2.18 1.95 0 2.45 5.91 2.21 5.91 6.35 0 2.05-1.51 3.29-3.32 3.56z"></path></svg>
              </div>
           </div>

           <!-- Help Box -->
           <div class="bg-white rounded-2xl p-8 text-center shadow-sm border border-gray-100">
               <div class="w-12 h-12 bg-[#E0F7FA] text-[#2EC4B6] rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"></path></svg>
               </div>
               <h3 class="font-bold text-gray-900 mb-1">Butuh Bantuan?</h3>
               <p class="text-gray-500 text-xs mb-4">Tim kami siap membantu 24/7</p>
               <a href="#" class="text-[#2EC4B6] font-bold text-sm hover:underline flex items-center justify-center gap-1">
                  Chat dengan CS
                  <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
               </a>
           </div>

        </div>

      </div>

      <!-- No data fallback -->
      <div v-else class="text-center py-20">
        <div class="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
        </div>
        <h3 class="font-bold text-gray-900 text-xl mb-2">Tidak Ada Data</h3>
        <p class="text-gray-500 mb-6">Silakan kembali dan coba cari tagihan lagi.</p>
        <button @click="goBack" class="bg-primary text-white px-6 py-3 rounded-xl font-bold hover:bg-teal-600 transition-colors">
          Kembali ke Beranda
        </button>
      </div>
    </div>

    <!-- Payment Modal -->
    <div v-if="showPaymentModal" class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" @click.self="showPaymentModal = false">
      <div class="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl transform transition-all">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Pilih Metode Pembayaran</h2>
          <button @click="showPaymentModal = false" class="text-gray-400 hover:text-gray-600 transition-colors">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
          </button>
        </div>

        <div class="bg-[#E0F7FA] border border-[#2EC4B6] rounded-xl p-4 mb-6">
          <div class="text-xs text-[#00838F] font-bold uppercase mb-1">Total Tagihan</div>
          <div class="text-3xl font-bold text-[#006064]">{{ formatRupiah(totalTagihan) }}</div>
        </div>

        <div class="space-y-3">
          <!-- E-Wallet Options -->
          <div class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">E-Wallet</div>
          <button class="w-full p-4 border-2 border-gray-200 rounded-xl hover:border-[#2EC4B6] hover:bg-[#E0F7FA]/30 transition-all flex items-center gap-3">
            <div class="w-12 h-12 bg-blue-500 rounded-lg flex items-center justify-center text-white font-bold">GO</div>
            <div class="text-left flex-1">
              <div class="font-bold text-gray-900">GoPay</div>
              <div class="text-xs text-gray-500">Bayar dengan GoPay</div>
            </div>
            <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
          </button>

          <button class="w-full p-4 border-2 border-gray-200 rounded-xl hover:border-[#2EC4B6] hover:bg-[#E0F7FA]/30 transition-all flex items-center gap-3">
            <div class="w-12 h-12 bg-purple-500 rounded-lg flex items-center justify-center text-white font-bold">OVO</div>
            <div class="text-left flex-1">
              <div class="font-bold text-gray-900">OVO</div>
              <div class="text-xs text-gray-500">Bayar dengan OVO</div>
            </div>
            <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
          </button>

          <button class="w-full p-4 border-2 border-gray-200 rounded-xl hover:border-[#2EC4B6] hover:bg-[#E0F7FA]/30 transition-all flex items-center gap-3">
            <div class="w-12 h-12 bg-red-500 rounded-lg flex items-center justify-center text-white font-bold">LK</div>
            <div class="text-left flex-1">
              <div class="font-bold text-gray-900">LinkAja</div>
              <div class="text-xs text-gray-500">Bayar dengan LinkAja</div>
            </div>
            <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
          </button>

          <!-- Bank Transfer -->
          <div class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2 mt-6">Transfer Bank</div>
          <button class="w-full p-4 border-2 border-gray-200 rounded-xl hover:border-[#2EC4B6] hover:bg-[#E0F7FA]/30 transition-all flex items-center gap-3">
            <div class="w-12 h-12 bg-blue-700 rounded-lg flex items-center justify-center text-white font-bold">BCA</div>
            <div class="text-left flex-1">
              <div class="font-bold text-gray-900">Bank BCA</div>
              <div class="text-xs text-gray-500">Transfer ke rekening BCA</div>
            </div>
            <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
          </button>

          <button class="w-full p-4 border-2 border-gray-200 rounded-xl hover:border-[#2EC4B6] hover:bg-[#E0F7FA]/30 transition-all flex items-center gap-3">
            <div class="w-12 h-12 bg-red-600 rounded-lg flex items-center justify-center text-white font-bold">BNI</div>
            <div class="text-left flex-1">
              <div class="font-bold text-gray-900">Bank BNI</div>
              <div class="text-xs text-gray-500">Transfer ke rekening BNI</div>
            </div>
            <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
          </button>
        </div>

        <p class="text-xs text-gray-500 text-center mt-6">💡 Pilih metode pembayaran untuk melanjutkan</p>
      </div>
    </div>

    <!-- Payment Methods Info Modal -->
    <div v-if="showPaymentMethodsModal" class="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" @click.self="showPaymentMethodsModal = false">
      <div class="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto p-6 shadow-2xl">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Cara Pembayaran</h2>
          <button @click="showPaymentMethodsModal = false" class="text-gray-400 hover:text-gray-600 transition-colors">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
          </button>
        </div>

        <!-- E-Wallet Section -->
        <div class="mb-8">
          <h3 class="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
            <span class="w-8 h-8 bg-[#2EC4B6] rounded-lg flex items-center justify-center text-white text-sm">💳</span>
            Pembayaran via E-Wallet
          </h3>
          <div class="bg-gray-50 rounded-xl p-4 space-y-3">
            <div class="flex items-start gap-3">
              <span class="w-6 h-6 bg-[#2EC4B6] rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0">1</span>
              <p class="text-sm text-gray-700">Pilih metode pembayaran e-Wallet (GoPay, OVO, atau LinkAja)</p>
            </div>
            <div class="flex items-start gap-3">
              <span class="w-6 h-6 bg-[#2EC4B6] rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0">2</span>
              <p class="text-sm text-gray-700">Scan QR Code yang muncul dengan aplikasi e-Wallet Anda</p>
            </div>
            <div class="flex items-start gap-3">
              <span class="w-6 h-6 bg-[#2EC4B6] rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0">3</span>
              <p class="text-sm text-gray-700">Konfirmasi pembayaran di aplikasi</p>
            </div>
            <div class="flex items-start gap-3">
              <span class="w-6 h-6 bg-[#2EC4B6] rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0">4</span>
              <p class="text-sm text-gray-700">Pembayaran berhasil! Tagihan akan otomatis terupdate</p>
            </div>
          </div>
        </div>

        <!-- Bank Transfer Section -->
        <div class="mb-8">
          <h3 class="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
            <span class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white text-sm">🏦</span>
            Pembayaran via Transfer Bank
          </h3>
          <div class="space-y-4">
            <!-- BCA -->
            <div class="bg-blue-50 border border-blue-200 rounded-xl p-4">
              <div class="flex items-center gap-3 mb-3">
                <div class="w-10 h-10 bg-blue-700 rounded-lg flex items-center justify-center text-white font-bold text-sm">BCA</div>
                <div>
                  <div class="font-bold text-gray-900">Bank BCA</div>
                  <div class="text-xs text-gray-500">a.n. HIPPAMS Tirto Joyo</div>
                </div>
              </div>
              <div class="bg-white rounded-lg p-3 border border-blue-200">
                <div class="text-xs text-gray-500 mb-1">Nomor Rekening</div>
                <div class="text-lg font-bold text-gray-900 tracking-wider">1234 5678 9012</div>
              </div>
            </div>

            <!-- BNI -->
            <div class="bg-red-50 border border-red-200 rounded-xl p-4">
              <div class="flex items-center gap-3 mb-3">
                <div class="w-10 h-10 bg-red-600 rounded-lg flex items-center justify-center text-white font-bold text-sm">BNI</div>
                <div>
                  <div class="font-bold text-gray-900">Bank BNI</div>
                  <div class="text-xs text-gray-500">a.n. HIPPAMS Tirto Joyo</div>
                </div>
              </div>
              <div class="bg-white rounded-lg p-3 border border-red-200">
                <div class="text-xs text-gray-500 mb-1">Nomor Rekening</div>
                <div class="text-lg font-bold text-gray-900 tracking-wider">9876 5432 1098</div>
              </div>
            </div>
          </div>

          <div class="bg-amber-50 border border-amber-200 rounded-xl p-4 mt-4">
            <div class="flex gap-3">
              <svg class="w-5 h-5 text-amber-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>
              <div class="text-sm text-amber-800">
                <p class="font-bold mb-1">Penting!</p>
                <p>Setelah transfer, mohon konfirmasi dengan mengirim bukti transfer ke WhatsApp: <span class="font-bold">0857-8446-6697</span></p>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-gray-100 rounded-xl p-4 text-center">
          <p class="text-sm text-gray-600">💡 Butuh bantuan? Hubungi Customer Service kami</p>
        </div>
      </div>
    </div>
  </div>
</template>
