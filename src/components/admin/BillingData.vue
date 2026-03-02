<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { MagnifyingGlassIcon, PencilSquareIcon, CheckCircleIcon, XCircleIcon, DocumentTextIcon, PrinterIcon, XMarkIcon, CurrencyDollarIcon, ExclamationTriangleIcon, PlusCircleIcon } from '@heroicons/vue/24/outline'
import jsPDF from 'jspdf'
import autoTable from 'jspdf-autotable'

// ==================== STATE ====================
const tagihans = ref([])
const isLoading = ref(false)

// Filter State
const filterYear = ref(new Date().getFullYear())
const filterMonth = ref(null) // null = all months
const filterStatus = ref('all')
const searchQuery = ref('')

// Pagination
const currentPage = ref(1)
const itemsPerPage = ref(10)
const totalItems = ref(0)
const totalPages = ref(0)

// Stats State
const stats = ref({
  total_biaya_air: 0,
  total_admin: 0,
  total_pendapatan: 0,
  total_tunggakan: 0
})


// Cicilan Modal State
const showCicilanModal = ref(false)
const currentTagihan = ref(null)
const cicilanAmount = ref(0)

// Input Tunggakan Modal State
const showTunggakanModal = ref(false)
const tunggakanAmount = ref(0)
const tunggakanKeterangan = ref('')

// Breakdown Tooltip State
const showBreakdown = ref(null) // ID of tagihan showing breakdown

// Toast Notifications
const toasts = ref([])
let toastId = 0

// Month options
const monthOptions = [
  { value: null, label: 'Semua Bulan' },
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
const getMonthLabel = (month) => {
  const found = monthOptions.find(m => m.value === parseInt(month))
  return found ? found.label : month
}

// Helper to check if arrears > 3 months (for color coding)
const isOverdueWarning = (tagihan) => {
  return tagihan.bulan_tunggakan && tagihan.bulan_tunggakan >= 3
}

// Toggle breakdown tooltip
const toggleBreakdown = (tagihanId) => {
  showBreakdown.value = showBreakdown.value === tagihanId ? null : tagihanId
}

// Live preview for cicilan
const previewRemainingTunggakan = computed(() => {
  if (!currentTagihan.value) return 0
  const current = parseFloat(currentTagihan.value.tunggakan || 0)
  const payment = parseFloat(cicilanAmount.value || 0)
  return Math.max(0, current - payment)
})

const previewNewTotal = computed(() => {
  if (!currentTagihan.value) return 0
  return parseFloat(currentTagihan.value.biaya_pemakaian) + previewRemainingTunggakan.value
})

// Pagination
const goToPage = (page) => {
  if (page >= 1 && page <= totalPages.value) {
    currentPage.value = page
    fetchTagihans()
  }
}

// ==================== TOAST FUNCTIONS ====================
const showToast = (message, type = 'success') => {
  const id = ++toastId
  toasts.value.push({ id, message, type })
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }, 4000)
}

// ==================== API FUNCTIONS ====================
const API_BASE = '/api/tagihan.php'

const fetchTagihans = async () => {
  isLoading.value = true
  try {
    const params = new URLSearchParams()
    if (filterYear.value) params.append('year', filterYear.value)
    if (filterMonth.value) params.append('month', filterMonth.value)
    if (filterStatus.value && filterStatus.value !== 'all') params.append('status', filterStatus.value)
    if (searchQuery.value) params.append('search', searchQuery.value)
    
    params.append('page', currentPage.value)
    params.append('limit', itemsPerPage.value)
    
    const response = await fetch(`${API_BASE}?${params.toString()}`)
    const data = await response.json()
    if (data.success) {
      tagihans.value = data.data
      if (data.pagination) {
        totalItems.value = data.pagination.total_items
        totalPages.value = data.pagination.total_pages
      }
      if (data.stats) {
        stats.value = data.stats
      }
    } else {
      showToast('Gagal memuat data tagihan', 'error')
    }
  } catch (error) {
    console.error('Fetch error:', error)
    showToast('Gagal memuat data tagihan', 'error')
  } finally {
    isLoading.value = false
  }
}

const toggleStatus = async (tagihan) => {
  const newStatus = tagihan.status === 'paid' ? 'unpaid' : 'paid'
  
  try {
    const response = await fetch(`${API_BASE}?action=status&id=${tagihan.input_meter_id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: newStatus })
    })
    const data = await response.json()
    
    if (data.success) {
      tagihan.status = data.data.status
      tagihan.paid_at = data.data.paid_at
      showToast(data.message, 'success')
    } else {
      showToast(data.message || 'Gagal mengubah status', 'error')
    }
  } catch (error) {
    showToast('Gagal mengubah status', 'error')
  }
}

// ==================== CICILAN FUNCTIONS ====================
const openCicilanModal = (tagihan) => {
  if (!tagihan.tunggakan || parseFloat(tagihan.tunggakan) <= 0) {
    showToast('Tidak ada tunggakan untuk tagihan ini', 'error')
    return
  }
  currentTagihan.value = tagihan
  cicilanAmount.value = 0
  showCicilanModal.value = true
}

const closeCicilanModal = () => {
  showCicilanModal.value = false
  currentTagihan.value = null
  cicilanAmount.value = 0
}

const saveCicilan = async () => {
  if (!currentTagihan.value) return
  
  const payment = parseFloat(cicilanAmount.value || 0)
  const currentTunggakan = parseFloat(currentTagihan.value.tunggakan || 0)
  
  if (payment <= 0) {
    showToast('Nominal cicilan harus lebih dari 0', 'error')
    return
  }
  
  if (payment > currentTunggakan) {
    showToast(`Nominal cicilan tidak boleh lebih dari tunggakan (Rp ${currentTunggakan.toLocaleString('id-ID')})`, 'error')
    return
  }
  
  isLoading.value = true
  try {
    const newTunggakan = currentTunggakan - payment
    
    const response = await fetch(`${API_BASE}?action=cicilan&id=${currentTagihan.value.input_meter_id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        cicilan_amount: payment,
        new_tunggakan: newTunggakan
      })
    })
    const data = await response.json()
    
    if (data.success) {
      showToast(data.message || `Cicilan berhasil dibayar (Rp ${payment.toLocaleString('id-ID')})`, 'success')
      closeCicilanModal()
      
      // CRITICAL: Refresh all data to get updated tunggakan for all months
      await fetchTagihans()
    } else {
      showToast(data.message || 'Gagal menyimpan cicilan', 'error')
    }
  } catch (error) {
    console.error('Cicilan error:', error)
    showToast('Gagal menyimpan cicilan', 'error')
  } finally {
    isLoading.value = false
  }
}

// ==================== INPUT TUNGGAKAN FUNCTIONS ====================
const openTunggakanModal = (tagihan) => {
  currentTagihan.value = tagihan
  tunggakanAmount.value = 0
  tunggakanKeterangan.value = ''
  showTunggakanModal.value = true
}

const closeTunggakanModal = () => {
  showTunggakanModal.value = false
  currentTagihan.value = null
  tunggakanAmount.value = 0
  tunggakanKeterangan.value = ''
}

const saveTunggakan = async () => {
  if (!currentTagihan.value) return
  
  const nominal = parseFloat(tunggakanAmount.value || 0)
  
  if (nominal <= 0) {
    showToast('Nominal tunggakan harus lebih dari 0', 'error')
    return
  }
  
  isLoading.value = true
  try {
    const response = await fetch(`${API_BASE}?action=add_tunggakan&id=${currentTagihan.value.input_meter_id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        tunggakan_tambahan: nominal,
        keterangan: tunggakanKeterangan.value
      })
    })
    const data = await response.json()
    
    if (data.success) {
      showToast(data.message || `Tunggakan berhasil ditambahkan (Rp ${nominal.toLocaleString('id-ID')})`, 'success')
      closeTunggakanModal()
      
      // Refresh data
      await fetchTagihans()
    } else {
      showToast(data.message || 'Gagal menambahkan tunggakan', 'error')
    }
  } catch (error) {
    console.error('Tunggakan error:', error)
    showToast('Gagal menambahkan tunggakan', 'error')
  } finally {
    isLoading.value = false
  }
}

// ==================== MODAL FUNCTIONS ====================
const printInvoice = (tagihan) => {
  // Simple print functionality - can be enhanced later
  const content = `
    INVOICE TAGIHAN AIR
    ====================
    ID Pelanggan: ${tagihan.customer_id}
    Nama: ${tagihan.pelanggan_name}
    Alamat: ${tagihan.pelanggan_address}
    Periode: ${getMonthLabel(tagihan.period_month)} ${tagihan.period_year}
    
    Pemakaian: ${tagihan.jumlah_pakai} m³
    Biaya Pemakaian: Rp ${parseFloat(tagihan.biaya_pemakaian).toLocaleString('id-ID')}
    Tunggakan: Rp ${parseFloat(tagihan.tunggakan).toLocaleString('id-ID')}
    ---------------------
    TOTAL TAGIHAN: Rp ${parseFloat(tagihan.total_tagihan).toLocaleString('id-ID')}
    
    Status: ${tagihan.status === 'paid' ? 'LUNAS' : 'BELUM BAYAR'}
  `
  const printWindow = window.open('', '_blank')
  printWindow.document.write(`<pre style="font-family: monospace; padding: 20px;">${content}</pre>`)
  printWindow.document.close()
  printWindow.print()
}

// ==================== WHATSAPP FUNCTIONS ====================
// Normalize phone number: Convert 08xxx to 628xxx for Indonesian numbers
const normalizePhoneNumber = (phone) => {
  if (!phone) return null
  // Remove all non-digit characters
  let cleaned = phone.replace(/\D/g, '')
  // Replace leading 0 with 62 (Indonesia country code)
  if (cleaned.startsWith('0')) {
    cleaned = '62' + cleaned.slice(1)
  }
  // Validate minimum length (10 digits after country code)
  if (cleaned.length < 10) return null
  return cleaned
}

// Generate WhatsApp message with dynamic data
const generateWhatsAppMessage = (tagihan) => {
  const message = `Halo Bapak/Ibu *${tagihan.pelanggan_name}*, kami dari HIPPAMS Tirto Joyo menginformasikan bahwa tagihan air periode *${getMonthLabel(tagihan.period_month)} ${tagihan.period_year}* sebesar *Rp ${parseFloat(tagihan.total_tagihan).toLocaleString('id-ID')}* (termasuk tunggakan) belum terbayar. Mohon segera melakukan pembayaran. Terima kasih.`
  return encodeURIComponent(message)
}

// Send WhatsApp reminder
const sendWhatsAppReminder = (tagihan) => {
  const phone = normalizePhoneNumber(tagihan.pelanggan_phone)
  if (!phone) {
    showToast('Nomor telepon pelanggan tidak valid atau kosong', 'error')
    return
  }
  const message = generateWhatsAppMessage(tagihan)
  const waUrl = `https://wa.me/${phone}?text=${message}`
  window.open(waUrl, '_blank')
}

// ==================== EXPORT PDF FUNCTIONS ====================
const exportToPDF = async () => {
  // Fetch ALL data (no pagination) for PDF export
  isLoading.value = true
  let allData = []
  try {
    const params = new URLSearchParams()
    if (filterYear.value) params.append('year', filterYear.value)
    if (filterMonth.value) params.append('month', filterMonth.value)
    if (filterStatus.value && filterStatus.value !== 'all') params.append('status', filterStatus.value)
    if (searchQuery.value) params.append('search', searchQuery.value)
    params.append('export', 'all') // Skip pagination, fetch all data
    
    const response = await fetch(`${API_BASE}?${params.toString()}`)
    const result = await response.json()
    if (result.success && result.data.length > 0) {
      allData = result.data
    } else {
      showToast('Tidak ada data untuk diexport', 'error')
      isLoading.value = false
      return
    }
  } catch (error) {
    console.error('Export fetch error:', error)
    showToast('Gagal mengambil data untuk export', 'error')
    isLoading.value = false
    return
  }
  isLoading.value = false
  
  const ADMIN_FEE = 2000
  
  const periodLabel = filterMonth.value 
    ? `${getMonthLabel(filterMonth.value)} ${filterYear.value}` 
    : `Tahun ${filterYear.value}`
  
  // Calculate totals — biaya_pemakaian from backend includes admin, so we separate them
  const totalPemakaian = allData.reduce((sum, t) => sum + parseFloat(t.jumlah_pakai || 0), 0)
  const totalBiayaPakai = allData.reduce((sum, t) => sum + (parseFloat(t.biaya_pemakaian || 0) - ADMIN_FEE), 0)
  const totalAdmin = allData.length * ADMIN_FEE
  const totalTunggakan = allData.reduce((sum, t) => sum + parseFloat(t.tunggakan || 0), 0)
  const totalTagihan = totalBiayaPakai + totalAdmin + totalTunggakan
  
  const dataLunas = allData.filter(t => t.status === 'paid')
  const dataBelum = allData.filter(t => t.status !== 'paid')
  const totalTerbayar = dataLunas.reduce((sum, t) => sum + parseFloat(t.total_tagihan || 0), 0)
  const totalPiutang = dataBelum.reduce((sum, t) => sum + parseFloat(t.total_tagihan || 0), 0)
  
  // Format currency helper
  const formatRp = (val) => 'Rp ' + parseFloat(val || 0).toLocaleString('id-ID')
  
  // Create PDF - F4 Landscape (215.9mm x 330mm)
  const doc = new jsPDF({
    orientation: 'landscape',
    unit: 'mm',
    format: [215.9, 330]
  })
  
  const pageWidth = doc.internal.pageSize.getWidth()
  const pageHeight = doc.internal.pageSize.getHeight()
  const margin = 15
  let yPos = margin
  
  // ==================== HEADER (first page only drawn here) ====================
  const drawHeader = (d) => {
    let y = margin
    d.setFont('helvetica', 'bold')
    d.setFontSize(18)
    d.setTextColor(0, 0, 0)
    d.text('HIPPAMS TIRTO JOYO', pageWidth / 2, y, { align: 'center' })
    y += 7
    d.setFont('helvetica', 'normal')
    d.setFontSize(10)
    d.text('GEMPOLPAYUNG, GEMPOL TUKMLOKO, SARIREJO LAMONGAN', pageWidth / 2, y, { align: 'center' })
    y += 10
    d.setLineWidth(0.8)
    d.line(margin, y, pageWidth - margin, y)
    y += 1.5
    d.setLineWidth(0.3)
    d.line(margin, y, pageWidth - margin, y)
    y += 8
    d.setFont('helvetica', 'bold')
    d.setFontSize(14)
    d.text('LAPORAN REKAPITULASI TAGIHAN AIR', pageWidth / 2, y, { align: 'center' })
    y += 6
    d.setFont('helvetica', 'normal')
    d.setFontSize(11)
    d.text(`Periode: ${periodLabel}`, pageWidth / 2, y, { align: 'center' })
    y += 4
    d.setFontSize(9)
    d.setTextColor(100, 100, 100)
    d.setTextColor(0, 0, 0)
    y += 8
    return y
  }
  
  // Draw header on first page
  yPos = drawHeader(doc)
  
  // ==================== TABLE ====================
  const tableColumns = [
    { header: 'No', dataKey: 'no' },
    { header: 'ID Pelanggan', dataKey: 'customer_id' },
    { header: 'Nama Pelanggan', dataKey: 'nama' },
    { header: 'Alamat', dataKey: 'alamat' },
    { header: 'M. Awal', dataKey: 'meter_awal' },
    { header: 'M. Akhir', dataKey: 'meter_akhir' },
    { header: 'Pakai (M³)', dataKey: 'pemakaian' },
    { header: 'Biaya Pakai', dataKey: 'biaya' },
    { header: 'Admin', dataKey: 'admin' },
    { header: 'Tunggakan', dataKey: 'tunggakan' },
    { header: 'Total Tagihan', dataKey: 'total' },
    { header: 'Status', dataKey: 'status' }
  ]
  
  const tableData = allData.map((t, index) => {
    const biayaPakai = parseFloat(t.biaya_pemakaian || 0) - ADMIN_FEE
    const tunggakan = parseFloat(t.tunggakan || 0)
    const totalPerRow = biayaPakai + ADMIN_FEE + tunggakan
    return {
      no: index + 1,
      customer_id: t.customer_id || '-',
      nama: t.pelanggan_name || '-',
      alamat: (t.pelanggan_address || '-').substring(0, 20),
      meter_awal: t.meter_awal || 0,
      meter_akhir: t.meter_akhir || 0,
      pemakaian: t.jumlah_pakai || 0,
      biaya: formatRp(biayaPakai),
      admin: formatRp(ADMIN_FEE),
      tunggakan: formatRp(tunggakan),
      total: formatRp(totalPerRow),
      status: t.status === 'paid' ? 'LUNAS' : 'BELUM'
    }
  })
  
  // Add totals footer row
  tableData.push({
    no: '',
    customer_id: '',
    nama: 'TOTAL',
    alamat: '',
    meter_awal: '',
    meter_akhir: '',
    pemakaian: totalPemakaian,
    biaya: formatRp(totalBiayaPakai),
    admin: formatRp(totalAdmin),
    tunggakan: formatRp(totalTunggakan),
    total: formatRp(totalTagihan),
    status: ''
  })
  
  let tableEndY = yPos
  let totalPagesCount = 0
  
  autoTable(doc, {
    startY: yPos,
    columns: tableColumns,
    body: tableData,
    theme: 'grid',
    showHead: 'everyPage', // Repeat table header on every page
    headStyles: {
      fillColor: [243, 244, 246],
      textColor: [0, 0, 0],
      fontStyle: 'bold',
      fontSize: 9,
      halign: 'center'
    },
    bodyStyles: {
      fontSize: 9,
      cellPadding: 2.5
    },
    alternateRowStyles: {
      fillColor: [249, 250, 251]
    },
    columnStyles: {
      no: { halign: 'center', cellWidth: 10 },
      customer_id: { halign: 'center', cellWidth: 22 },
      nama: { cellWidth: 'auto' },
      alamat: { cellWidth: 'auto' },
      meter_awal: { halign: 'center', cellWidth: 18 },
      meter_akhir: { halign: 'center', cellWidth: 18 },
      pemakaian: { halign: 'center', cellWidth: 18 },
      biaya: { halign: 'right', cellWidth: 30 },
      admin: { halign: 'right', cellWidth: 20 },
      tunggakan: { halign: 'right', cellWidth: 30 },
      total: { halign: 'right', cellWidth: 32 },
      status: { halign: 'center', cellWidth: 18 }
    },
    margin: { left: margin, right: margin, top: margin + 5, bottom: margin + 10 },
    didParseCell: function(data) {
      if (data.column.dataKey === 'status' && data.section === 'body') {
        if (data.cell.raw === 'LUNAS') {
          data.cell.styles.textColor = [34, 197, 94]
          data.cell.styles.fontStyle = 'bold'
        } else if (data.cell.raw === 'BELUM') {
          data.cell.styles.textColor = [239, 68, 68]
          data.cell.styles.fontStyle = 'bold'
        }
      }
      // Style the totals footer row (last row)
      if (data.section === 'body' && data.row.index === tableData.length - 1) {
        data.cell.styles.fillColor = [229, 231, 235]
        data.cell.styles.fontStyle = 'bold'
        data.cell.styles.textColor = [0, 0, 0]
      }
    },
    didDrawPage: function(data) {
      tableEndY = data.cursor.y
      totalPagesCount = doc.internal.getNumberOfPages()
      
      // Draw page number footer on every page
      const pageNum = doc.internal.getCurrentPageInfo().pageNumber
      doc.setFont('helvetica', 'normal')
      doc.setFontSize(8)
      doc.setTextColor(150, 150, 150)
      doc.text(
        `Halaman ${pageNum}`,
        pageWidth / 2,
        pageHeight - 8,
        { align: 'center' }
      )
      doc.setTextColor(0, 0, 0)
    }
  })
  
  // ==================== SUMMARY & SIGNATURES (after table) ====================
  // Check if enough space on current page, else add new page
  yPos = tableEndY + 10
  const neededSpace = 70 // space needed for summary + signatures
  
  if (yPos + neededSpace > pageHeight - margin) {
    doc.addPage()
    yPos = margin + 10
  }
  
  // ==================== SUMMARY BLOCK ====================
  const summaryX = margin
  const summaryWidth = 130
  
  doc.setFillColor(243, 244, 246)
  doc.roundedRect(summaryX, yPos, summaryWidth, 58, 3, 3, 'F')
  
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(11)
  doc.setTextColor(0, 0, 0)
  doc.text('RINGKASAN FINANSIAL', summaryX + 5, yPos + 8)
  
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(9)
  
  const summaryData = [
    ['Total Pemakaian Air:', `${totalPemakaian.toLocaleString('id-ID')} M³`],
    ['Total Biaya Pakai:', formatRp(totalBiayaPakai)],
    ['Total Admin:', formatRp(totalAdmin)],
    ['Total Tunggakan:', formatRp(totalTunggakan)],
    ['Total Tagihan Keseluruhan:', formatRp(totalTagihan)],
    ['Total Pendapatan (Lunas):', formatRp(totalTerbayar)],
    ['Total Piutang (Belum Bayar):', formatRp(totalPiutang)]
  ]
  
  let summaryY = yPos + 15
  summaryData.forEach(([label, value], idx) => {
    if (idx === 4) {
      doc.setDrawColor(150, 150, 150)
      doc.setLineWidth(0.3)
      doc.line(summaryX + 5, summaryY - 2, summaryX + summaryWidth - 5, summaryY - 2)
    }
    doc.setFont('helvetica', 'normal')
    doc.text(label, summaryX + 5, summaryY)
    doc.setFont('helvetica', idx === 4 ? 'bold' : 'normal')
    doc.text(value, summaryX + 65, summaryY)
    summaryY += 7
  })
  
  // ==================== SIGNATURES ====================
  const signY = yPos + 5
  const signWidth = 60
  const sign1X = pageWidth - margin - signWidth * 2 - 20
  const sign2X = pageWidth - margin - signWidth
  
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(9)
  
  const now = new Date()
  const printDate = now.toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' }) + 
                    ' ' + now.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
  doc.text(`Dicetak: ${printDate}`, sign1X, signY)
  
  doc.text('Pelaksana Kas,', sign1X + 10, signY + 12)
  doc.setFont('helvetica', 'bold')
  doc.text('M. ROFI\'I', sign1X + 10, signY + 38)
  
  doc.setFont('helvetica', 'normal')
  doc.text('Ketua,', sign2X + 10, signY + 12)
  doc.setFont('helvetica', 'bold')
  doc.text('ACH. HABIBUR ROHMAN, S.E.', sign2X + 10, signY + 38)
  
  // ==================== SAVE PDF ====================
  const filename = `Laporan_Tagihan_${periodLabel.replace(/\s/g, '_')}.pdf`
  doc.save(filename)
  
  showToast(`Berhasil export ${allData.length} data ke PDF`, 'success')
}

// Watch for filter changes
watch([filterYear, filterMonth, filterStatus], () => {
  currentPage.value = 1
  fetchTagihans()
})

// Debounced search
let searchTimeout
watch(searchQuery, () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    currentPage.value = 1
    fetchTagihans()
  }, 500)
})

onMounted(() => {
  fetchTagihans()
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
        <h2 class="text-2xl font-bold text-gray-900">Data Tagihan</h2>
        <p class="text-gray-500">Monitor status pembayaran dan kelola tunggakan pelanggan.</p>
      </div>
      <button 
        @click="exportToPDF"
        class="inline-flex items-center gap-2 px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-xl font-bold transition-all shadow-lg shadow-red-500/30"
      >
        <DocumentTextIcon class="w-5 h-5" />
        Export PDF
      </button>
    </div>

    <!-- Stats Cards -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Total Biaya Air -->
      <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 transition-all hover:shadow-md">
        <div class="w-12 h-12 rounded-xl bg-blue-50 flex items-center justify-center text-blue-600">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"></path></svg>
        </div>
        <div>
          <p class="text-sm font-medium text-gray-500">Total Biaya Air</p>
          <p class="text-xl font-bold text-gray-900">Rp {{ stats.total_biaya_air.toLocaleString('id-ID') }}</p>
        </div>
      </div>

      <!-- Total Admin -->
      <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 transition-all hover:shadow-md">
        <div class="w-12 h-12 rounded-xl bg-purple-50 flex items-center justify-center text-purple-600">
          <CheckCircleIcon class="w-6 h-6" />
        </div>
        <div>
          <p class="text-sm font-medium text-gray-500">Total Admin</p>
          <p class="text-xl font-bold text-gray-900">Rp {{ stats.total_admin.toLocaleString('id-ID') }}</p>
        </div>
      </div>

      <!-- Total Pendapatan -->
      <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 transition-all hover:shadow-md">
        <div class="w-12 h-12 rounded-xl bg-green-50 flex items-center justify-center text-green-600">
          <CurrencyDollarIcon class="w-6 h-6" />
        </div>
        <div>
          <p class="text-sm font-medium text-gray-500">Total Pendapatan</p>
          <p class="text-xl font-bold text-gray-900">Rp {{ stats.total_pendapatan.toLocaleString('id-ID') }}</p>
        </div>
      </div>

      <!-- Total Tunggakan -->
      <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4 transition-all hover:shadow-md text-red-600">
        <div class="w-12 h-12 rounded-xl bg-red-50 flex items-center justify-center text-red-600">
          <ExclamationTriangleIcon class="w-6 h-6" />
        </div>
        <div>
          <p class="text-sm font-medium text-red-500">Total Tunggakan</p>
          <p class="text-xl font-bold">Rp {{ stats.total_tunggakan.toLocaleString('id-ID') }}</p>
        </div>
      </div>
    </div>

    <!-- Filter -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-4">
      <div class="flex flex-wrap items-center gap-4">
        <!-- Search -->
        <div class="flex-1 min-w-[200px]">
          <div class="relative">
            <MagnifyingGlassIcon class="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Cari ID Pelanggan atau Nama..."
              class="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50"
            >
          </div>
        </div>
        <!-- Periode Filter -->
        <div class="flex items-center gap-2">
          <label class="text-sm font-medium text-gray-600">Periode:</label>
          <select 
            v-model="filterMonth"
            class="px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
          >
            <option v-for="m in monthOptions" :key="m.value" :value="m.value">{{ m.label }}</option>
          </select>
          <select 
            v-model="filterYear"
            class="px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/50 bg-white"
          >
            <option v-for="y in [2026, 2027, 2028, 2029, 2030]" :key="y" :value="y">{{ y }}</option>
          </select>
        </div>
        <!-- Status Filter -->
        <div class="flex gap-2">
          <button 
            @click="filterStatus = 'all'"
            :class="[
              'px-4 py-2 rounded-lg text-sm font-medium transition-all',
              filterStatus === 'all' ? 'bg-primary text-white shadow-md' : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
            ]"
          >
            Semua
          </button>
          <button 
            @click="filterStatus = 'paid'"
            :class="[
              'px-4 py-2 rounded-lg text-sm font-medium transition-all',
              filterStatus === 'paid' ? 'bg-green-500 text-white shadow-md' : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
            ]"
          >
            Lunas
          </button>
          <button 
            @click="filterStatus = 'unpaid'"
            :class="[
              'px-4 py-2 rounded-lg text-sm font-medium transition-all',
              filterStatus === 'unpaid' ? 'bg-amber-500 text-white shadow-md' : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
            ]"
          >
            Belum Bayar
          </button>
        </div>
      </div>
    </div>

    <!-- Table -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
      <!-- Loading -->
      <div v-if="isLoading" class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>
      
      <!-- Empty State -->
      <div v-else-if="tagihans.length === 0" class="text-center py-12">
        <DocumentTextIcon class="w-12 h-12 mx-auto text-gray-300 mb-4" />
        <p class="text-gray-500">{{ searchQuery ? 'Tidak ada data yang cocok' : 'Belum ada data tagihan untuk periode ini' }}</p>
      </div>
      
      <!-- Data Table -->
      <div v-else class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-primary text-white font-bold uppercase text-xs">
            <tr>
              <th class="px-6 py-4 text-left">ID Pelanggan</th>
              <th class="px-6 py-4 text-left">Nama & Alamat</th>
              <th class="px-6 py-4 text-left">Periode</th>
              <th class="px-6 py-4 text-right">Biaya Pemakaian</th>
              <th class="px-6 py-4 text-right">Tunggakan</th>
              <th class="px-6 py-4 text-right">Total Tagihan</th>
              <th class="px-6 py-4 text-center">Status</th>
              <th class="px-6 py-4 text-center">Aksi</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <tr 
              v-for="tagihan in tagihans" 
              :key="tagihan.input_meter_id" 
              :class="[
                'transition-colors relative',
                isOverdueWarning(tagihan) ? 'bg-red-50 hover:bg-red-100' : 'hover:bg-frozen/20'
              ]"
            >
              <!-- Warning Indicator -->
              <td class="px-6 py-4 font-mono text-gray-600 font-medium relative">
                <div class="flex items-center gap-2">
                  <span>{{ tagihan.customer_id }}</span>
                  <span 
                    v-if="isOverdueWarning(tagihan)" 
                    class="px-2 py-0.5 bg-red-500 text-white text-[10px] font-bold rounded-full animate-pulse"
                    title="Tunggakan >3 Bulan - Peringatan Putus"
                  >
                    !
                  </span>
                </div>
              </td>
              <td class="px-6 py-4">
                <div class="font-bold text-gray-900">{{ tagihan.pelanggan_name }}</div>
                <div class="text-sm text-gray-500 truncate max-w-xs">{{ tagihan.pelanggan_address }}</div>
              </td>
              <td class="px-6 py-4 text-gray-600">{{ getMonthLabel(tagihan.period_month) }} {{ tagihan.period_year }}</td>
              <td class="px-6 py-4 text-right font-medium">
                <span class="text-gray-700">Rp {{ parseFloat(tagihan.biaya_pemakaian).toLocaleString('id-ID') }}</span>
                <div class="text-xs text-gray-400">{{ tagihan.jumlah_pakai }} m³</div>
              </td>
              
              <!-- Tunggakan Column with Breakdown Tooltip -->
              <td class="px-6 py-4 text-right relative">
                <button 
                  v-if="parseFloat(tagihan.tunggakan) > 0"
                  @click="toggleBreakdown(tagihan.input_meter_id)"
                  @mouseleave="showBreakdown = null"
                  class="group cursor-pointer"
                >
                  <div class="flex items-center justify-end gap-1">
                    <span class="text-red-600 font-bold">
                      Rp {{ parseFloat(tagihan.tunggakan).toLocaleString('id-ID') }}
                    </span>
                    <span class="text-red-500 text-xs">
                      ({{ tagihan.bulan_tunggakan || 0 }} bln)
                    </span>
                  </div>
                  <div class="text-[10px] text-red-400 uppercase tracking-wider">Akumulasi</div>
                  
                  <!-- Breakdown Tooltip -->
                  <div 
                    v-if="showBreakdown === tagihan.input_meter_id && tagihan.tunggakan_breakdown"
                    class="absolute right-0 top-full mt-2 bg-white border-2 border-red-200 rounded-lg shadow-2xl p-4 z-50 min-w-[300px]"
                  >
                    <div class="text-xs font-bold text-gray-700 mb-2 text-left">Rincian Tunggakan:</div>
                    <div class="space-y-1 max-h-48 overflow-y-auto">
                      <div 
                        v-for="(item, idx) in tagihan.tunggakan_breakdown" 
                        :key="idx"
                        class="flex justify-between text-xs text-left border-b border-gray-100 pb-1"
                      >
                        <span class="text-gray-600">
                          {{ getMonthLabel(item.period_month) }} {{ item.period_year }}
                        </span>
                        <span class="font-bold text-red-600">
                          Rp {{ parseFloat(item.amount).toLocaleString('id-ID') }}
                        </span>
                      </div>
                    </div>
                    <div class="border-t-2 border-red-300 mt-2 pt-2 flex justify-between font-bold text-sm">
                      <span class="text-gray-700">Total:</span>
                      <span class="text-red-600">Rp {{ parseFloat(tagihan.tunggakan).toLocaleString('id-ID') }}</span>
                    </div>
                  </div>
                </button>
                <span v-else class="text-gray-400">Rp 0</span>
              </td>
              
              <td class="px-6 py-4 text-right">
                <span class="text-xl font-bold text-amber-500">
                  Rp {{ parseFloat(tagihan.total_tagihan).toLocaleString('id-ID') }}
                </span>
              </td>
              <td class="px-6 py-4 text-center">
                <button 
                  @click="toggleStatus(tagihan)"
                  :class="[
                    'px-3 py-1 rounded-full text-xs font-bold border cursor-pointer transition-all hover:scale-105',
                    tagihan.status === 'paid' 
                      ? 'bg-green-50 text-green-700 border-green-200 hover:bg-green-100' 
                      : 'bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-100'
                  ]"
                >
                  {{ tagihan.status === 'paid' ? 'Lunas' : 'Belum Bayar' }}
                </button>
              </td>
              <td class="px-6 py-4">
                <div class="flex items-center justify-center gap-2">
                  <button 
                    v-if="parseFloat(tagihan.tunggakan) > 0"
                    @click="openCicilanModal(tagihan)"
                    class="p-2 text-amber-600 hover:bg-amber-50 rounded-full transition-colors"
                    title="Bayar Cicilan"
                  >
                    <CurrencyDollarIcon class="w-5 h-5" />
                  </button>
                  <!-- Input Tunggakan Button -->
                  <button 
                    @click="openTunggakanModal(tagihan)"
                    class="p-2 text-red-500 hover:bg-red-50 rounded-full transition-colors"
                    title="Tambah Tunggakan"
                  >
                    <PlusCircleIcon class="w-5 h-5" />
                  </button>
                  <!-- WhatsApp Button - Only show for unpaid bills -->
                  <button 
                    v-if="tagihan.status !== 'paid'"
                    @click="sendWhatsAppReminder(tagihan)"
                    class="p-2 rounded-full transition-colors group"
                    :class="tagihan.pelanggan_phone ? 'text-[#25D366] hover:bg-green-50' : 'text-gray-300 cursor-not-allowed'"
                    :title="tagihan.pelanggan_phone ? 'Kirim Tagihan WA' : 'Nomor telepon tidak tersedia'"
                    :disabled="!tagihan.pelanggan_phone"
                  >
                    <!-- WhatsApp Icon SVG -->
                    <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
                    </svg>
                  </button>
                  <button 
                    @click="printInvoice(tagihan)"
                    class="p-2 text-gray-600 hover:bg-gray-100 rounded-full transition-colors"
                    title="Cetak Invoice"
                  >
                    <PrinterIcon class="w-5 h-5" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <!-- Pagination -->
      <div class="px-6 py-4 border-t border-gray-100 flex flex-col sm:flex-row items-center justify-between gap-4">
        <div class="text-sm text-gray-500">
          Menampilkan {{ tagihans.length }} dari {{ totalItems }} data
        </div>
        <div v-if="totalPages > 1" class="flex items-center gap-2">
          <button @click="goToPage(1)" :disabled="currentPage === 1" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">&laquo;</button>
          <button @click="goToPage(currentPage - 1)" :disabled="currentPage === 1" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">&lsaquo;</button>
          <template v-for="page in totalPages" :key="page">
            <button 
              v-if="page === 1 || page === totalPages || (page >= currentPage - 1 && page <= currentPage + 1)"
              @click="goToPage(page)"
              class="px-3 py-1.5 text-sm rounded-lg border transition-colors"
              :class="page === currentPage ? 'bg-primary text-white border-primary' : 'border-gray-200 hover:bg-gray-50'"
            >{{ page }}</button>
            <span v-else-if="page === currentPage - 2 || page === currentPage + 2" class="text-gray-400">...</span>
          </template>
          <button @click="goToPage(currentPage + 1)" :disabled="currentPage === totalPages" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">&rsaquo;</button>
          <button @click="goToPage(totalPages)" :disabled="currentPage === totalPages" class="px-3 py-1.5 text-sm rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed">&raquo;</button>
        </div>
      </div>
    </div>

    <!-- Cicilan Payment Modal -->
    <Teleport to="body">
      <div v-if="showCicilanModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" @click="closeCicilanModal"></div>
        
        <!-- Modal Content -->
        <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 transform transition-all">
          <!-- Close Button -->
          <button 
            @click="closeCicilanModal"
            class="absolute top-4 right-4 p-1 text-gray-400 hover:text-gray-600 transition-colors"
          >
            <XMarkIcon class="w-6 h-6" />
          </button>
          
          <!-- Header -->
          <div class="flex items-center gap-3 mb-6">
            <div class="w-12 h-12 rounded-xl bg-amber-500 flex items-center justify-center">
              <CurrencyDollarIcon class="w-7 h-7 text-white" />
            </div>
            <div>
              <h3 class="text-xl font-bold text-gray-900">Bayar Cicilan</h3>
              <p class="text-sm text-gray-500">Pembayaran sebagian tunggakan</p>
            </div>
          </div>
          
          <!-- Customer Info -->
          <div v-if="currentTagihan" class="mb-6 p-4 bg-frozen/30 rounded-xl border border-frozen">
            <div class="space-y-2 text-sm">
              <div class="flex justify-between">
                <span class="text-gray-500">Nama Pelanggan:</span>
                <span class="font-bold text-gray-900">{{ currentTagihan.pelanggan_name }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-500">Periode:</span>
                <span class="font-bold text-gray-900">{{ getMonthLabel(currentTagihan.period_month) }} {{ currentTagihan.period_year }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-500">Biaya Pemakaian:</span>
                <span class="font-bold text-gray-900">Rp {{ parseFloat(currentTagihan.biaya_pemakaian).toLocaleString('id-ID') }}</span>
              </div>
              <div class="flex justify-between border-t border-gray-200 pt-2">
                <span class="text-red-600 font-semibold">Tunggakan Saat Ini:</span>
                <span class="font-bold text-red-600">Rp {{ parseFloat(currentTagihan.tunggakan).toLocaleString('id-ID') }}</span>
              </div>
            </div>
          </div>
          
          <!-- Cicilan Input -->
          <div class="mb-6">
            <label class="block text-sm font-medium text-gray-700 mb-2">Nominal Pembayaran Cicilan</label>
            <div class="relative">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-500 font-medium">Rp</span>
              <input 
                v-model.number="cicilanAmount"
                type="number"
                min="0"
                :max="currentTagihan?.tunggakan || 0"
                class="w-full pl-12 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-amber-500/50 text-lg font-bold"
                placeholder="0"
              >
            </div>
            <p class="text-xs text-gray-500 mt-1">Maksimal: Rp {{ parseFloat(currentTagihan?.tunggakan || 0).toLocaleString('id-ID') }}</p>
          </div>
          
          <!-- Live Preview -->
          <div class="mb-6 p-4 bg-gradient-to-r from-amber-500 to-orange-500 text-white rounded-xl">
            <div class="grid grid-cols-2 gap-4 mb-3">
              <div>
                <div class="text-xs text-white/80 mb-1">Sisa Tunggakan</div>
                <div class="text-lg font-bold">
                  Rp {{ previewRemainingTunggakan.toLocaleString('id-ID') }}
                </div>
              </div>
              <div>
                <div class="text-xs text-white/80 mb-1">Total Tagihan Baru</div>
                <div class="text-lg font-bold">
                  Rp {{ previewNewTotal.toLocaleString('id-ID') }}
                </div>
              </div>
            </div>
            <div v-if="previewRemainingTunggakan === 0" class="text-xs text-white/90 flex items-center gap-1">
              <CheckCircleIcon class="w-4 h-4" />
              Status akan berubah menjadi <span class="font-bold">LUNAS</span>
            </div>
          </div>
          
          <!-- Buttons -->
          <div class="flex items-center justify-end gap-3">
            <button 
              @click="closeCicilanModal"
              class="px-6 py-2.5 rounded-xl text-gray-600 font-bold hover:bg-gray-100 transition-colors border border-gray-200"
            >
              Batal
            </button>
            <button 
              @click="saveCicilan"
              :disabled="isLoading || cicilanAmount <= 0"
              class="px-6 py-2.5 rounded-xl bg-amber-500 text-white font-bold shadow-lg shadow-amber-500/30 hover:bg-amber-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ isLoading ? 'Menyimpan...' : 'Bayar Cicilan' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Input Tunggakan Modal -->
    <Teleport to="body">
      <div v-if="showTunggakanModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" @click="closeTunggakanModal"></div>
        
        <!-- Modal Content -->
        <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-md transform transition-all">
          <!-- Header -->
          <div class="bg-gradient-to-r from-red-500 to-orange-500 text-white px-6 py-4 rounded-t-2xl flex items-center justify-between">
            <div class="flex items-center gap-3">
              <ExclamationTriangleIcon class="w-6 h-6" />
              <h3 class="text-lg font-bold">Tambah Tunggakan</h3>
            </div>
            <button @click="closeTunggakanModal" class="p-1 hover:bg-white/20 rounded-full transition-colors">
              <XMarkIcon class="w-6 h-6" />
            </button>
          </div>
          
          <!-- Body -->
          <div class="p-6">
            <!-- Customer Info -->
            <div class="mb-6 p-4 bg-gray-50 rounded-xl border border-gray-100">
              <div class="space-y-2 text-sm" v-if="currentTagihan">
                <div class="flex justify-between">
                  <span class="text-gray-500">Pelanggan:</span>
                  <span class="font-bold text-gray-900">{{ currentTagihan.pelanggan_name }}</span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-500">Periode:</span>
                  <span class="font-bold text-gray-900">{{ getMonthLabel(currentTagihan.period_month) }} {{ currentTagihan.period_year }}</span>
                </div>
                <div class="flex justify-between border-t border-gray-200 pt-2">
                  <span class="text-gray-500">Tunggakan Saat Ini:</span>
                  <span class="font-bold text-red-600">Rp {{ parseFloat(currentTagihan.tunggakan || 0).toLocaleString('id-ID') }}</span>
                </div>
              </div>
            </div>
            
            <!-- Tunggakan Amount Input -->
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-2">Nominal Tunggakan Tambahan</label>
              <div class="relative">
                <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-500 font-medium">Rp</span>
                <input 
                  v-model.number="tunggakanAmount"
                  type="number"
                  min="0"
                  class="w-full pl-12 pr-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-red-500/50 text-lg font-bold"
                  placeholder="0"
                >
              </div>
            </div>
            
            <!-- Keterangan Input -->
            <div class="mb-6">
              <label class="block text-sm font-medium text-gray-700 mb-2">Keterangan (Opsional)</label>
              <input 
                v-model="tunggakanKeterangan"
                type="text"
                class="w-full px-4 py-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-red-500/50"
                placeholder="Contoh: Tunggakan tahun lalu, Denda, dll"
              >
            </div>
            
            <!-- Preview -->
            <div class="mb-6 p-4 bg-gradient-to-r from-red-500 to-orange-500 text-white rounded-xl" v-if="currentTagihan">
              <div class="flex justify-between items-center">
                <span class="text-white/80">Total Tunggakan Baru:</span>
                <span class="text-xl font-bold">
                  Rp {{ (parseFloat(currentTagihan.tunggakan || 0) + tunggakanAmount).toLocaleString('id-ID') }}
                </span>
              </div>
            </div>
          
            <!-- Buttons -->
            <div class="flex items-center justify-end gap-3">
              <button 
                @click="closeTunggakanModal"
                class="px-6 py-2.5 rounded-xl text-gray-600 font-bold hover:bg-gray-100 transition-colors border border-gray-200"
              >
                Batal
              </button>
              <button 
                @click="saveTunggakan"
                :disabled="isLoading || tunggakanAmount <= 0"
                class="px-6 py-2.5 rounded-xl bg-red-500 text-white font-bold shadow-lg shadow-red-500/30 hover:bg-red-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {{ isLoading ? 'Menyimpan...' : 'Tambah Tunggakan' }}
              </button>
            </div>
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
