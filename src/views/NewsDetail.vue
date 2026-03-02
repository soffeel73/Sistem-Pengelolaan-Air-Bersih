<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Header from '../components/Header.vue'
import Footer from '../components/Footer.vue'

const route = useRoute()
const router = useRouter()
const berita = ref(null)
const loading = ref(true)
const relatedNews = ref([])

const API_BASE = '/api/konten.php'

const fetchBeritaDetail = async () => {
  const id = route.params.id
  try {
    const res = await fetch(`${API_BASE}?action=berita`)
    const data = await res.json()
    if (data.success) {
      berita.value = data.data.find(b => b.id == id)
      // Get related news (excluding current)
      relatedNews.value = data.data
        .filter(b => b.id != id && b.status === 'published')
        .slice(0, 3)
    }
  } catch (e) {
    console.error('Error:', e)
  } finally {
    loading.value = false
  }
}

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  return date.toLocaleDateString('id-ID', { 
    weekday: 'long',
    day: 'numeric', 
    month: 'long', 
    year: 'numeric' 
  })
}

const goBack = () => router.push('/news')
const goToNews = (id) => router.push(`/news/${id}`)

onMounted(() => {
  fetchBeritaDetail()
})

// Watch for route changes to refetch
import { watch } from 'vue'
watch(() => route.params.id, () => {
  if (route.params.id) {
    loading.value = true
    fetchBeritaDetail()
  }
})
</script>

<template>
  <div class="min-h-screen bg-gradient-to-br from-[#F0FBFA] to-[#E0F7FA]">
    <Header />
    
    <main class="pt-24 pb-16">
      <div class="container mx-auto px-4 lg:px-8">
        <!-- Loading -->
        <div v-if="loading" class="flex justify-center py-20">
          <div class="animate-spin rounded-full h-12 w-12 border-4 border-primary border-t-transparent"></div>
        </div>

        <!-- Not Found -->
        <div v-else-if="!berita" class="text-center py-20">
          <svg class="w-24 h-24 text-gray-300 mx-auto mb-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M12 2C6.477 2 2 6.477 2 12s4.477 10 10 10 10-4.477 10-10S17.523 2 12 2z"></path>
          </svg>
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Berita Tidak Ditemukan</h2>
          <button @click="goBack" class="px-6 py-3 bg-primary text-white rounded-xl font-medium hover:bg-teal-600">
            Kembali ke Arsip Berita
          </button>
        </div>

        <!-- Article Content -->
        <article v-else class="max-w-4xl mx-auto">
          <!-- Back Button -->
          <button 
            @click="goBack"
            class="mb-8 flex items-center gap-2 text-primary hover:text-teal-700 transition-colors font-medium"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            Kembali ke Arsip Berita
          </button>

          <!-- Article Header -->
          <header class="mb-8">
            <div class="flex items-center gap-3 text-sm text-gray-500 mb-4">
              <span class="px-3 py-1 bg-primary/10 text-primary font-bold rounded-full">Berita</span>
              <span>•</span>
              <time>{{ formatDate(berita.tanggal_publish) }}</time>
            </div>
            <h1 class="text-3xl lg:text-4xl font-bold text-gray-900 leading-tight mb-6">
              {{ berita.judul }}
            </h1>
            <p v-if="berita.ringkasan" class="text-xl text-gray-600 leading-relaxed border-l-4 border-primary pl-4">
              {{ berita.ringkasan }}
            </p>
          </header>

          <!-- Featured Image -->
          <div v-if="berita.foto_url" class="mb-8 rounded-2xl overflow-hidden shadow-xl">
            <img 
              :src="berita.foto_url" 
              :alt="berita.judul"
              class="w-full aspect-video object-cover"
            />
          </div>

          <!-- Article Body -->
          <div class="prose prose-lg max-w-none mb-12">
            <div class="bg-white rounded-2xl p-8 shadow-sm border border-gray-100">
              <div 
                class="text-gray-700 leading-relaxed text-lg content-rich"
                v-html="berita.isi_berita"
              ></div>
            </div>
          </div>

          <!-- Share Section -->
          <div class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 mb-12">
            <div class="flex items-center justify-between flex-wrap gap-4">
              <div class="flex items-center gap-3">
                <span class="text-gray-600 font-medium">Bagikan:</span>
                <div class="flex gap-2">
                  <button class="w-10 h-10 rounded-full bg-blue-500 text-white flex items-center justify-center hover:bg-blue-600 transition-colors">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M24 4.557c-.883.392-1.832.656-2.828.775 1.017-.609 1.798-1.574 2.165-2.724-.951.564-2.005.974-3.127 1.195-.897-.957-2.178-1.555-3.594-1.555-3.179 0-5.515 2.966-4.797 6.045-4.091-.205-7.719-2.165-10.148-5.144-1.29 2.213-.669 5.108 1.523 6.574-.806-.026-1.566-.247-2.229-.616-.054 2.281 1.581 4.415 3.949 4.89-.693.188-1.452.232-2.224.084.626 1.956 2.444 3.379 4.6 3.419-2.07 1.623-4.678 2.348-7.29 2.04 2.179 1.397 4.768 2.212 7.548 2.212 9.142 0 14.307-7.721 13.995-14.646.962-.695 1.797-1.562 2.457-2.549z"/></svg>
                  </button>
                  <button class="w-10 h-10 rounded-full bg-blue-600 text-white flex items-center justify-center hover:bg-blue-700 transition-colors">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M9 8h-3v4h3v12h5v-12h3.642l.358-4h-4v-1.667c0-.955.192-1.333 1.115-1.333h2.885v-5h-3.808c-3.596 0-5.192 1.583-5.192 4.615v3.385z"/></svg>
                  </button>
                  <button class="w-10 h-10 rounded-full bg-green-500 text-white flex items-center justify-center hover:bg-green-600 transition-colors">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z"/></svg>
                  </button>
                </div>
              </div>
              <button @click="goBack" class="px-6 py-2.5 bg-gray-100 text-gray-700 rounded-xl font-medium hover:bg-gray-200 transition-colors">
                Lihat Berita Lainnya
              </button>
            </div>
          </div>

          <!-- Related News -->
          <section v-if="relatedNews.length > 0">
            <h2 class="text-2xl font-bold text-gray-900 mb-6">Berita Terkait</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <article 
                v-for="news in relatedNews" 
                :key="news.id"
                @click="goToNews(news.id)"
                class="group cursor-pointer bg-white rounded-xl overflow-hidden shadow-sm border border-gray-100 hover:shadow-lg transition-all"
              >
                <div class="aspect-video bg-gray-100 overflow-hidden">
                  <img 
                    v-if="news.foto_url" 
                    :src="news.foto_url" 
                    :alt="news.judul"
                    class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  />
                  <div v-else class="w-full h-full bg-gradient-to-br from-primary/20 to-primary/5 flex items-center justify-center">
                    <svg class="w-10 h-10 text-primary/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z"></path>
                    </svg>
                  </div>
                </div>
                <div class="p-4">
                  <h3 class="font-bold text-gray-900 line-clamp-2 group-hover:text-primary transition-colors">
                    {{ news.judul }}
                  </h3>
                </div>
              </article>
            </div>
          </section>
        </article>
      </div>
    </main>

    <Footer />
  </div>
</template>

<style scoped>
/* CSS agar tag blockquote dan strong muncul dengan gaya */
.content-rich :deep(blockquote) {
  border-left: 5px solid #14b8a6; /* warna primary teal */
  margin: 1.5em 10px;
  padding: 0.5em 15px;
  font-style: italic;
  background-color: #f0fdfa;
  color: #374151;
}

.content-rich :deep(strong) {
  font-weight: 800;
  color: #111827;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
