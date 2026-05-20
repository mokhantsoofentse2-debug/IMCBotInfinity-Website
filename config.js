<script>
    const params = new URLSearchParams(window.location.search);
    const botType = params.get('bot');

    const botDatabase = {
        'sa': { title: "Small Account Setup", pass: "IMCBOTSA_9922", file: "files/IMCBOT_SA.mq5", class: "color-sa" },
        'master': { title: "Master Bot Setup", pass: "IMCBOTMaster_101033", file: "files/IMCBOT_Master.mq5", class: "color-master" },
        'king': { title: "King Bot Setup", pass: "IMCBOTKing_10111", file: "files/IMCBOT_KING.mq5", class: "color-king" },
        'asura': { title: "Asura Bot Setup", pass: "IMCBOTAsura_10112", file: "files/IMCBOT_ASURA.mq5", class: "color-asura" }
    };

    const currentBot = botDatabase[botType];
    if (currentBot) {
        const titleEl = document.getElementById('botTitle');
        titleEl.innerText = "IMCBOT " + currentBot.title;
        titleEl.className = currentBot.class; // Applies the specific color
    }

    function startSlideshow() {
        let current = 1;
        setInterval(() => {
            const img1 = document.getElementById('saver1');
            const img2 = document.getElementById('saver2');
            if (current === 1) {
                img1.classList.remove('active'); img2.classList.add('active'); current = 2;
            } else {
                img2.classList.remove('active'); img1.classList.add('active'); current = 1;
            }
        }, 5000);
    }

    function verifyBot() {
        const inputPass = document.getElementById('pass').value;
        const accNum = document.getElementById('accNum').value;
        const server = document.getElementById('server').value;
        const market = document.getElementById('market').value;
        
        if (!accNum || !server || !market) {
            alert("Please fill in all trading account details.");
            return;
        }

        if (currentBot && inputPass === currentBot.pass) {
            // STEP 3 LOGIC: This is where we send the data to your Oracle Cloud IP
            // Replace 'YOUR_ORACLE_IP' once your VPS is live
            fetch('http://YOUR_ORACLE_IP:5000/trade', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                    account: accNum, 
                    action: 'CONNECT', 
                    symbol: market,
                    bot: botType 
                })
            }).catch(err => console.log("Cloud not active yet, but logic is ready."));

            // UI Changes
            const btn = document.getElementById('verifyBtn');
            btn.innerText = "Trading Sync Active!";
            btn.style.background = "#444";
            btn.disabled = true;
            
            document.getElementById('downloadArea').style.display = 'block';
            document.getElementById('botLink').href = currentBot.file;
            document.getElementById('successView').style.display = 'block';
            startSlideshow();
        } else {
            alert("Incorrect password.");
        }
    }
</script>
