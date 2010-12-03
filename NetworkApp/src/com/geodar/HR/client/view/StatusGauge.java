package com.geodar.HR.client.view;

import com.google.gwt.core.client.GWT;
import com.google.gwt.http.client.Request;
import com.google.gwt.http.client.RequestBuilder;
import com.google.gwt.http.client.RequestCallback;
import com.google.gwt.http.client.RequestException;
import com.google.gwt.http.client.Response;
import com.google.gwt.http.client.URL;
import com.google.gwt.json.client.JSONArray;
import com.google.gwt.json.client.JSONException;
import com.google.gwt.json.client.JSONNumber;
import com.google.gwt.json.client.JSONObject;
import com.google.gwt.json.client.JSONParser;
import com.google.gwt.json.client.JSONValue;
import com.google.gwt.user.client.Timer;
import com.google.gwt.user.client.Window;
import com.google.gwt.user.client.ui.Label;
import com.google.gwt.user.client.ui.VerticalPanel;
import com.google.gwt.visualization.client.AbstractDataTable.ColumnType;
import com.google.gwt.visualization.client.DataTable;
import com.google.gwt.visualization.client.VisualizationUtils;
import com.google.gwt.visualization.client.visualizations.Gauge;

public class StatusGauge extends VerticalPanel {
	
	private Gauge gauge;
	private Gauge.Options options;
	private String url;
	private String query;
	private DataTable data;
	private Timer timer;
	private RequestBuilder builder;
	final Label nameField = new Label();
	
	public StatusGauge(String query,String title, final int start, final int end) {
		this.query = query;

		this.url = URL.encode("http://"+Window.Location.getHost()+Configuration.GaugeURL+query);
		GWT.log(this.url);
		builder = new RequestBuilder(RequestBuilder.GET, this.url);
		nameField.setText(title);
		
		Runnable onLoadCallback = new Runnable() {

			public void run() {

				options = Gauge.Options.create();
				options.setWidth(Configuration.GaugeX);
				options.setHeight(Configuration.GaugeX);
				options.setGaugeRange(start, end);
				options.setMinorTicks(Configuration.GaugeTicks);
//				options.setGreenRange(start+10, end-10);
//				options.setYellowRange(start, end);

				getData();

				timer = new Timer() {

					public void run() {
						updateGraph();

						// GWT.log("tick");
					}

				};
				timer.scheduleRepeating(Configuration.GaugeRefresh);
				gauge = new Gauge(data, options);
				add(nameField);
				add(gauge);

			}

		};

		VisualizationUtils.loadVisualizationApi(onLoadCallback, Gauge.PACKAGE);
	}

	private void getData() {
		data = DataTable.create();
		data.addColumn(ColumnType.STRING, "Category");
		data.addColumn(ColumnType.NUMBER, "Value");
		data.addRows(1);
		data.setValue(0, 0, query);
		updateGraph();

	}

	public void setUpdateInterval(int ms) {
		timer.scheduleRepeating(ms);

	}

	private void updateGraph() {

		try {
			builder.sendRequest(null, new RequestCallback() {
				public void onError(Request request, Throwable exception) {
					GWT.log("Couldn't retrieve JSON");
				}

				public void onResponseReceived(Request request, Response response) {
					if (200 == response.getStatusCode()) {
						try {
							// parse the response text into JSON
							JSONValue jsonValue = JSONParser.parseStrict(response.getText());
							JSONArray jsonArray = jsonValue.isArray();

							if (jsonArray != null) {
								updateTable(jsonArray);
							} else {
								throw new JSONException();
							}
						} catch (JSONException e) {

							GWT.log("Could not parse JSON");
							GWT.log(e.toString());

							// e.printStackTrace();
						}
					} else {
						GWT.log("Couldn't retrieve JSON (" + response.getStatusText() + ")");
					}
				}

			});
		} catch (RequestException e) {
			GWT.log("Couldn't retrieve JSON");
		} catch (Exception e) {
			GWT.log(e.toString());
		}
	}

	private void updateTable(JSONArray array) {
		JSONValue jsonValue;

		JSONObject jsStock;
		JSONNumber jsPrice;

		if ((jsStock = array.get(0).isObject()) == null) {
			// error
		}

		if ((jsonValue = jsStock.get("value")) == null) {
			// error
		}

		if ((jsPrice = jsonValue.isNumber()) == null) {

		}
		//GWT.log("got:" + jsonValue.toString());
		data.setValue(0, 1, jsPrice.doubleValue());
//		data.setFormattedValue(0, 1, jsonValue.toString()+"C");
//		GWT.log(""+data.getFormattedValue(0,1));
		gauge.draw(data, options);

	}
}