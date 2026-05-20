<script>
    const params = new URLSearchParams(window.location.search);
    const botType = params.get('bot');

    // Central Database for your bots
    const botDatabase = {
        'sa': {
            title: "Small Account Setup",
            pass: "IMCBOTSA_9922",
            file: "files/IMCBOT_SA.mq5"
        },
        'master': {
            title: "Master Bot Setup",
            pass: "IMCBOTMaster_101033", 
            file: "files/IMCBOT_Master.mq5"
        },
        'king': {
            title: "King Bot Setup",
            pass: "IMCBOTKing_10111",
            file: "files/IMCBOT_KING.mq5"
        },
        'asura': {
            title: "Asura Bot Setup",
            pass: "IMCBOTAsura_10112",
            file: "files/IMCBOT_ASURA.mq5"
        }
    };

    // Initialize Page
    const currentBot = botDatabase[botType];
    if (currentBot) {
        document.getElementById('botTitle').innerText = "IMCBOT " + currentBot.title;
    } else {
        document.getElementById('botTitle').innerText = "Invalid Bot Selected";
    }

// Replaced new
function verifyBot() {
    const market = document.getElementById('market').value;
    
    // Example: Sending a signal to a free Firebase Realtime Database
    fetch('https://your-project-id.firebaseio.com/commands.json', {
        method: 'PUT',
        body: JSON.stringify({ 
            action: 'buy', 
            symbol: market, 
            timestamp: Date.now() 
        })
    }).then(() => {
        document.getElementById('verifyBtn').innerText = "Signal Sent to Cloud!";
    });
}
</script>
