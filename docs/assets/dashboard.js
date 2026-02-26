document.addEventListener('DOMContentLoaded', () => {
    // Chart instances
    let accuracyChart = null;
    let latencyChart = null;

    // Chart.js global defaults for dark mode premium aesthetic
    Chart.defaults.color = '#8b949e';
    Chart.defaults.font.family = "'Inter', sans-serif";
    Chart.defaults.scale.grid.color = 'rgba(255, 255, 255, 0.05)';
    
    const accuracyCtx = document.getElementById('accuracyChart').getContext('2d');
    const latencyCtx = document.getElementById('latencyChart').getContext('2d');
    const datasetSelect = document.getElementById('dataset-select');

    // Function to fetch and process dataset
    async function loadDataset(datasetId) {
        try {
            // Fetch both summary and metadata in parallel
            const [summaryResponse, metadataResponse] = await Promise.all([
                fetch(`results/${datasetId}/summary.json`),
                fetch(`results/${datasetId}/metadata.json`).catch(() => null) // Optional metadata
            ]);

            if (!summaryResponse.ok) {
                throw new Error(`Failed to load data for ${datasetId}: ${summaryResponse.statusText}`);
            }
            
            const data = await summaryResponse.json();
            const metadata = metadataResponse && metadataResponse.ok ? await metadataResponse.json() : null;
            
            // Extract the model statistics array
            // Format is likely { summary: [...] } from the markdown generation or a direct array
            const results = Array.isArray(data) ? data : (data.summary || Object.values(data).filter(v => v.model));
            
            if (!results || results.length === 0) {
                console.error("Data format not recognized or empty.", data);
                return;
            }

            // Sort results by accuracy (descending), then latency (ascending)
            results.sort((a, b) => {
                const accA = a.correct || 0;
                const accB = b.correct || 0;
                if (accB !== accA) return accB - accA;
                return (a.avg_latency_sec || 0) - (b.avg_latency_sec || 0);
            });

            renderCharts(results);
            if (metadata && metadata.model_stats) {
                renderModelDetails(results, metadata.model_stats);
            } else {
                document.getElementById('model-details-container').style.display = 'none';
            }

        } catch (error) {
            console.error('Error loading dataset:', error);
            // Fallback or error state could be shown here
        }
    }

    function renderModelDetails(results, modelStats) {
        const container = document.getElementById('model-details-container');
        const tbody = document.querySelector('#model-details-table tbody');
        
        // Show the container
        container.style.display = 'block';
        tbody.innerHTML = ''; // Clear existing rows
        
        // Sort models alphabetically for the table
        const sortedModels = [...results].sort((a, b) => a.model.localeCompare(b.model));
        
        sortedModels.forEach(row => {
            const stats = modelStats[row.model] || {};
            const sizeGb = stats.size ? (stats.size / (1024 * 1024 * 1024)).toFixed(2) : 'N/A';
            const params = stats.parameter_size || 'N/A';
            const quant = stats.quantization_level || 'N/A';
            const family = stats.family || 'N/A';
            
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td class="code-font">${row.model}</td>
                <td>${sizeGb}</td>
                <td>${params}</td>
                <td><span style="background: rgba(255,123,114,0.1); color: #ff7b72; padding: 2px 6px; border-radius: 4px; font-size: 0.8rem;">${quant}</span></td>
                <td>${family}</td>
            `;
            tbody.appendChild(tr);
        });
    }

    function renderCharts(results) {
        const labels = results.map(r => r.model);
        
        // Data for Accuracy Chart
        const correctData = results.map(r => r.correct || 0);
        const incorrectData = results.map(r => r.incorrect || 0);
        const errorData = results.map(r => r.errors || 0);

        // Data for Latency Chart
        const latencyData = results.map(r => r.avg_latency_sec || 0);

        // Destroy existing charts if they exist
        if (accuracyChart) accuracyChart.destroy();
        if (latencyChart) latencyChart.destroy();

        // 1. Accuracy Stacked Bar Chart
        accuracyChart = new Chart(accuracyCtx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Correct',
                        data: correctData,
                        backgroundColor: 'rgba(46, 160, 67, 0.8)', // Premium Green
                        borderColor: '#2ea043',
                        borderWidth: 1,
                        borderRadius: 4
                    },
                    {
                        label: 'Incorrect',
                        data: incorrectData,
                        backgroundColor: 'rgba(248, 81, 73, 0.8)', // Premium Red
                        borderColor: '#f85149',
                        borderWidth: 1,
                        borderRadius: 4
                    },
                    {
                        label: 'Errors',
                        data: errorData,
                        backgroundColor: 'rgba(210, 153, 34, 0.8)', // Premium Yellow
                        borderColor: '#d29922',
                        borderWidth: 1,
                        borderRadius: 4
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: {
                        stacked: true,
                    },
                    y: {
                        stacked: true,
                        beginAtZero: true,
                        ticks: { stepSize: 1 }
                    }
                },
                plugins: {
                    legend: {
                        position: 'top',
                        labels: { usePointStyle: true, boxWidth: 8 }
                    },
                    tooltip: {
                        mode: 'index',
                        intersect: false,
                        backgroundColor: 'rgba(13, 17, 23, 0.9)',
                        titleColor: '#fff',
                        bodyColor: '#c9d1d9',
                        borderColor: 'rgba(255, 255, 255, 0.1)',
                        borderWidth: 1
                    }
                },
                animation: {
                    duration: 1200,
                    easing: 'easeOutQuart'
                }
            }
        });

        // 2. Latency Bar Chart
        latencyChart = new Chart(latencyCtx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Avg Latency (s)',
                    data: latencyData,
                    backgroundColor: 'rgba(88, 166, 255, 0.8)', // Premium Blue
                    borderColor: '#58a6ff',
                    borderWidth: 1,
                    borderRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: { display: true, text: 'Seconds' }
                    }
                },
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(13, 17, 23, 0.9)',
                        titleColor: '#fff',
                        bodyColor: '#c9d1d9',
                        borderColor: 'rgba(255, 255, 255, 0.1)',
                        borderWidth: 1,
                        callbacks: {
                            label: function(context) {
                                return `Latency: ${context.parsed.y.toFixed(2)} s`;
                            }
                        }
                    }
                },
                animation: {
                    duration: 1200,
                    easing: 'easeOutQuart',
                    delay: 200 // Slight stagger
                }
            }
        });
    }

    // Event listener for dropdown
    datasetSelect.addEventListener('change', (e) => {
        loadDataset(e.target.value);
    });

    // Initial Load
    loadDataset(datasetSelect.value);
});
