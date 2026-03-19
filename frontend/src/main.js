import { createApp } from 'vue'
import App from './App.vue'

// 引入三大件
import router from './router'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'

const app = createApp(App)

// 依次挂载
app.use(router)
app.use(createPinia())
app.use(ElementPlus)

app.mount('#app')
