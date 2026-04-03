package com.arveya.arveygo.ui.screens.support

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Laptop
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.SupportAgent
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.theme.AppColors

private data class SupportFaq(val id: String, val question: String, val answer: String)
private data class SupportThread(val id: String, val title: String, val preview: String, val updatedAt: String, val status: String, val statusColor: Color)

private enum class SupportCategory(val label: String, val icon: ImageVector) {
    CONNECTION("Bağlantı", Icons.Default.WifiOff),
    DEVICE("Cihaz", Icons.Default.Memory),
    SOFTWARE("Yazılım", Icons.Default.Laptop),
    BILLING("Fatura", Icons.Default.CreditCard),
    INTEGRATION("Entegrasyon", Icons.Default.Sync),
    OTHER("Diğer", Icons.Default.MoreHoriz)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupportRequestScreen(onBack: () -> Unit, showSideMenu: (() -> Unit)? = null) {
    val colors = MaterialTheme.colorScheme
    var selectedCategory by remember { mutableStateOf(SupportCategory.CONNECTION) }
    var subject by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var contactEmail by remember { mutableStateOf("") }
    var contactPhone by remember { mutableStateOf("") }
    var selectedThread by remember { mutableStateOf<SupportThread?>(null) }
    var isSubmitted by remember { mutableStateOf(false) }
    val expandedFaqs = remember { mutableStateListOf("ownership") }
    val threads = remember {
        mutableStateListOf(
            SupportThread("1", "Socket bağlantısı kararsız", "Teknik ekip logları inceliyor.", "02.04.2026 17:40", "Açık", AppColors.Offline),
            SupportThread("2", "Araç eşleme sorusu", "Yeni cihaz aktivasyonu için ek bilgi bekleniyor.", "01.04.2026 10:15", "Yanıt Bekleniyor", AppColors.Idle)
        )
    }
    val faqItems = remember {
        listOf(
            SupportFaq("ownership", "Donanım mülkiyeti kime aittir?", "Satın alınan cihaz sizin mülkiyetinizde kalır. Cihaz kalitesi GPS doğruluğu ve kilometre güvenilirliğini doğrudan etkiler."),
            SupportFaq("compatibility", "Her marka cihaz kullanılabilir mi?", "Uyumlu cihazlar teknik ekip kontrolünden sonra mevcut filoya entegre edilebilir."),
            SupportFaq("subscription", "Aylık hizmet bedeli neleri kapsar?", "SIM veri, bulut altyapısı, harita hizmeti ve teknik destek aylık hizmet kapsamında yer alır."),
            SupportFaq("security", "Veri güvenliği nasıl sağlanır?", "Veriler şifreli aktarılır ve KVKK / GDPR prensiplerine uygun şekilde saklanır.")
        )
    }

    if (selectedThread != null) {
        AlertDialog(
            onDismissRequest = { selectedThread = null },
            title = { Text(selectedThread!!.title, fontWeight = FontWeight.SemiBold) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(selectedThread!!.preview, fontSize = 14.sp, color = colors.onSurface.copy(alpha = 0.72f))
                    Text(selectedThread!!.updatedAt, fontSize = 12.sp, color = colors.onSurface.copy(alpha = 0.5f))
                }
            },
            confirmButton = {
                TextButton(onClick = { selectedThread = null }) {
                    Text("Kapat")
                }
            }
        )
    }

    if (isSubmitted) {
        AlertDialog(
            onDismissRequest = { isSubmitted = false },
            title = { Text("Talep oluşturuldu", fontWeight = FontWeight.SemiBold) },
            text = { Text("Yeni destek talebin görüşmelerine eklendi ve ekip kuyruğuna aktarıldı.") },
            confirmButton = {
                TextButton(onClick = { isSubmitted = false }) {
                    Text("Tamam")
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowForward, null, tint = colors.onSurface, modifier = Modifier.size(18.dp))
                    }
                },
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text("Destek Merkezi", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurface)
                        Text("SSS, talepler ve görüşmeler", fontSize = 10.sp, color = colors.onSurface.copy(alpha = 0.55f))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.background)
            )
        },
        containerColor = colors.background
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            SupportCard {
                Row(verticalAlignment = Alignment.Top) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(52.dp)
                            .background(AppColors.Indigo.copy(alpha = 0.14f), RoundedCornerShape(16.dp))
                    ) {
                        Icon(Icons.Default.SupportAgent, null, tint = AppColors.Indigo, modifier = Modifier.size(22.dp))
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Destek akışını tek merkezden yönet", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurface)
                        Text("Sık sorulan soruları incele, yeni bir talep oluştur veya geçmiş görüşmelerine dön.", fontSize = 14.sp, color = colors.onSurface.copy(alpha = 0.68f))
                    }
                }
                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                    SupportStat("Açık", "${threads.count { it.status == "Açık" }}", AppColors.Offline, Modifier.weight(1f))
                    SupportStat("Yanıt Bekleyen", "${threads.count { it.status == "Yanıt Bekleniyor" }}", AppColors.Idle, Modifier.weight(1f))
                    SupportStat("Toplam", "${threads.size}", AppColors.Indigo, Modifier.weight(1f))
                }
                Spacer(Modifier.height(14.dp))
                Button(
                    onClick = {
                        WebSocketManager.reconnect()
                        onBack()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Navy),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Default.Refresh, null, tint = Color.White, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Bağlantıyı Yeniden Dene", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            SectionTitle("SSS", "En sık sorulan başlıklar")
            faqItems.forEach { item ->
                SupportCard {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                if (expandedFaqs.contains(item.id)) expandedFaqs.remove(item.id) else expandedFaqs.add(item.id)
                            },
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(item.question, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurface)
                        if (expandedFaqs.contains(item.id)) {
                            Text(item.answer, fontSize = 14.sp, color = colors.onSurface.copy(alpha = 0.68f))
                        }
                    }
                }
            }

            SectionTitle("Talep Oluştur", "Yeni görüşme başlat")
            SupportCard {
                SupportField("Konu", "Örn: Soket bağlantısı kararsız", subject) { subject = it }
                Spacer(Modifier.height(12.dp))
                Text("Kategori", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = colors.onSurface.copy(alpha = 0.7f))
                Spacer(Modifier.height(8.dp))
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    SupportCategory.entries.chunked(3).forEach { rowItems ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                            rowItems.forEach { category ->
                                val selected = selectedCategory == category
                                Surface(
                                    onClick = { selectedCategory = category },
                                    color = if (selected) AppColors.Navy.copy(alpha = 0.12f) else colors.surfaceVariant,
                                    shape = RoundedCornerShape(14.dp),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        verticalArrangement = Arrangement.spacedBy(6.dp),
                                        modifier = Modifier.padding(vertical = 12.dp)
                                    ) {
                                        Icon(category.icon, null, tint = if (selected) AppColors.Navy else colors.onSurface.copy(alpha = 0.6f), modifier = Modifier.size(16.dp))
                                        Text(category.label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = if (selected) AppColors.Navy else colors.onSurface.copy(alpha = 0.7f), maxLines = 1)
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
                SupportField("Detay", "Sorununuzu detaylıca açıklayın", description, minLines = 4) { description = it }
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                    SupportField("E-posta", "ornek@email.com", contactEmail, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Email) { contactEmail = it }
                    SupportField("Telefon", "+90 5XX", contactPhone, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Phone) { contactPhone = it }
                }
                Spacer(Modifier.height(14.dp))
                Button(
                    onClick = {
                        threads.add(
                            0,
                            SupportThread(
                                id = "${threads.size + 1}",
                                title = subject,
                                preview = description,
                                updatedAt = "03.04.2026 04:15",
                                status = "Açık",
                                statusColor = AppColors.Offline
                            )
                        )
                        subject = ""
                        description = ""
                        contactEmail = ""
                        contactPhone = ""
                        isSubmitted = true
                    },
                    enabled = subject.isNotBlank() && description.isNotBlank() && contactEmail.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Navy),
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier.fillMaxWidth().height(50.dp)
                ) {
                    Icon(Icons.Default.Send, null, tint = Color.White, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Talebi Gönder", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            SectionTitle("Görüşmelerim", "Son destek talepleri")
            SupportCard {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    threads.forEachIndexed { index, thread ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedThread = thread }
                                .padding(vertical = 4.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .background(thread.statusColor, CircleShape)
                            )
                            Spacer(Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(thread.title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = colors.onSurface, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text(thread.preview, fontSize = 12.sp, color = colors.onSurface.copy(alpha = 0.62f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                            Spacer(Modifier.width(10.dp))
                            Column(horizontalAlignment = Alignment.End) {
                                Text(thread.status, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = thread.statusColor)
                                Text(thread.updatedAt, fontSize = 11.sp, color = colors.onSurface.copy(alpha = 0.45f))
                            }
                        }
                        if (index < threads.lastIndex) {
                            HorizontalDivider(color = colors.outline.copy(alpha = 0.35f))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SupportCard(content: @Composable ColumnScope.() -> Unit) {
    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(18.dp), content = content)
    }
}

@Composable
private fun SupportStat(title: String, value: String, tint: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(14.dp))
            .border(1.dp, tint.copy(alpha = 0.18f), RoundedCornerShape(14.dp))
            .padding(horizontal = 12.dp, vertical = 12.dp)
    ) {
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
        Text(value, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun SectionTitle(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.padding(horizontal = 4.dp)) {
        Text(title, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
        Text(subtitle, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f))
    }
}

@Composable
private fun SupportField(
    title: String,
    placeholder: String,
    value: String,
    modifier: Modifier = Modifier,
    minLines: Int = 1,
    keyboardType: KeyboardType = KeyboardType.Text,
    onValueChange: (String) -> Unit
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, fontSize = 13.sp) },
            singleLine = minLines == 1,
            minLines = minLines,
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AppColors.Navy,
                unfocusedBorderColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f),
                focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant,
                focusedTextColor = MaterialTheme.colorScheme.onSurface,
                unfocusedTextColor = MaterialTheme.colorScheme.onSurface
            ),
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth()
        )
    }
}
